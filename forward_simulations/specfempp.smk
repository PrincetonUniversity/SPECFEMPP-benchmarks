
configfile: "config.yaml"


rule specfempp_all:
    input:
        profile=expand(
            "specfempp_workdir/{benchmark}/{machine}/results.csv",
            benchmark=config["benchmarks"].keys(),
            machine=config["resources"].keys(),
        ),
    localrule: True


rule specfempp_mesh_par_file:
    input:
        par_file="templates/{benchmark}/SPECFEMPP/Par_File",
        interfaces="templates/{benchmark}/SPECFEMPP/topography.dat",
    output:
        par_file="specfempp_workdir/{benchmark}/{machine}/{simulation}/mesh/mesh.par",
        interfaces="specfempp_workdir/{benchmark}/{machine}/{simulation}/mesh/topography.dat",
    params:
        mesh_output_folder="specfempp_workdir/{benchmark}/{machine}/{simulation}/mesh/OUTPUT_FILES",
        nx=lambda wildcards: config["benchmarks"][wildcards.benchmark][
            wildcards.machine
        ][wildcards.simulation]["nx"],
        nz=lambda wildcards: config["benchmarks"][wildcards.benchmark][
            wildcards.machine
        ][wildcards.simulation]["nz"],
    localrule: True
    run:
        import numpy as np
        import shutil

        nx = config["benchmarks"][wildcards.benchmark][wildcards.machine][
            wildcards.simulation
        ]["nx"]
        nz = config["benchmarks"][wildcards.benchmark][wildcards.machine][
            wildcards.simulation
        ]["nz"]

        nxmax = np.max(nx)
        nzmax = np.max(nz)

        format_dict = {}

        for i in range(len(nx)):
            format_dict[f"nx{i}"] = nx[i]

        format_dict["nxmax"] = nxmax

        for i in range(len(nz)):
            format_dict[f"nz{i}"] = nz[i]

        format_dict["nzmax"] = nzmax

        with open(input.par_file) as f:
            template = f.read()

        content = template.format(
            **format_dict,
            interfacesfile=output.interfaces,
            output_folder=params.mesh_output_folder,
        )

        with open(output.par_file, "w") as f:
            f.write(content)

        with open(input.interfaces, "r") as f:
            template = f.read()

        content = template.format(**format_dict)

        with open(output.interfaces, "w") as f:
            f.write(content)


rule specfempp_mesh:
    input:
        meshfem_bin=lambda wildcards: config["build_dir"]["specfempp"][wildcards.machine]
        + "/xmeshfem2D",
        par_file="specfempp_workdir/{benchmark}/{machine}/{simulation}/mesh/mesh.par",
    output:
        mesh="specfempp_workdir/{benchmark}/{machine}/{simulation}/mesh/OUTPUT_FILES/database.bin",
        stations="specfempp_workdir/{benchmark}/{machine}/{simulation}/mesh/OUTPUT_FILES/STATIONS",
    localrule: True
    shell:
        """
            module purge

            mkdir -p specfempp_workdir/{wildcards.benchmark}/{wildcards.machine}/{wildcards.simulation}/mesh/OUTPUT_FILES
            {input.meshfem_bin} -p {input.par_file}
        """


rule specfempp_specfem_config:
    input:
        specfem_config="templates/{benchmark}/SPECFEMPP/specfem_config.yaml.in",
        sources="templates/{benchmark}/SPECFEMPP/sources.yaml.in",
    output:
        specfem_config="specfempp_workdir/{benchmark}/{machine}/{simulation}/{repeat}/specfem_config.yaml",
        sources="specfempp_workdir/{benchmark}/{machine}/{simulation}/{repeat}/sources.yaml",
    params:
        mesh_database="specfempp_workdir/{benchmark}/{machine}/{simulation}/mesh/OUTPUT_FILES/database.bin",
        stations_file="specfempp_workdir/{benchmark}/{machine}/{simulation}/mesh/OUTPUT_FILES/STATIONS",
        work_directory="specfempp_workdir/{benchmark}/{machine}/{simulation}/{repeat}/",
    localrule: True
    run:
        with open(input.specfem_config, "r") as f:
            template = f.read()

        content = template.format(
            mesh_database=params.mesh_database,
            source_file=output.sources,
            stations_file=params.stations_file,
            work_directory=params.work_directory,
        )

        with open(output.specfem_config, "w") as f:
            f.write(content)

        with open(input.sources, "r") as f:
            template = f.read()

        with open(output.sources, "w") as f:
            f.write(template)


rule specfempp_solver:
    input:
        solver_bin=lambda wildcards: config["build_dir"]["specfempp"][wildcards.machine]
        + "/specfem2d",
        specfem_config="specfempp_workdir/{benchmark}/{machine}/{simulation}/{repeat}/specfem_config.yaml",
        sources="specfempp_workdir/{benchmark}/{machine}/{simulation}/{repeat}/sources.yaml",
        mesh_database="specfempp_workdir/{benchmark}/{machine}/{simulation}/mesh/OUTPUT_FILES/database.bin",
        stations_file="specfempp_workdir/{benchmark}/{machine}/{simulation}/mesh/OUTPUT_FILES/STATIONS",
    output:
        output="specfempp_workdir/{benchmark}/{machine}/{simulation}/{repeat}/output.log",
    params:
        work_directory="specfempp_workdir/{benchmark}/{machine}/{simulation}/{repeat}",
    resources:
        nodes=lambda wildcards: config["resources"][wildcards.machine]["nodes"],
        tasks=lambda wildcards: config["resources"][wildcards.machine]["tasks"],
        cpus_per_task=lambda wildcards: config["resources"][wildcards.machine][
            "cpus_per_task"
        ],
        runtime=lambda wildcards: config["resources"][wildcards.machine]["runtime"],
        constraint=lambda wildcards: config["resources"][wildcards.machine]["constraint"],
        mem_mb_per_cpu=lambda wildcards: config["resources"][wildcards.machine][
            "mem_mb_per_cpu"
        ],
        slurm_extra=lambda wildcards: config["resources"][wildcards.machine][
            "slurm_extra"
        ],
    shell:
        """
            module purge
            module load boost/1.73.0
            mkdir -p {params.work_directory}/seismograms

            echo "Hostname: $(hostname)" > {output.output}
            {input.solver_bin} -p {input.specfem_config} >> {output.output}
        """


rule specfempp_generate_profile:
    input:
        log="specfempp_workdir/{benchmark}/{machine}/{simulation}/{repeat}/output.log",
    output:
        profile="specfempp_workdir/{benchmark}/{machine}/{simulation}/{repeat}/profile.csv",
    params:
        nx=lambda wildcards: config["benchmarks"][wildcards.benchmark][
            wildcards.machine
        ][wildcards.simulation]["nx"][-1],
        nz=lambda wildcards: config["benchmarks"][wildcards.benchmark][
            wildcards.machine
        ][wildcards.simulation]["nz"][-1],
        repeat=lambda wildcards: wildcards.repeat,
    localrule: True
    shell:
        """
            SOLVER_TIME=$(grep "Total solver time" {input.log} | awk '{{print $7}}') && \
            HOSTNAME=$(grep "Hostname" {input.log} | awk '{{print $2}}') && \
            echo "{params.nx},{params.nz},{params.repeat},$SOLVER_TIME,$HOSTNAME" > {output.profile}
        """


rule specfempp_compile_results:
    input:
        ## use work_directories function to get list of work directories
        profile_files=expand(
            "specfempp_workdir/{benchmark}/{machine}/{simulation}/repeat_{repeat}/profile.csv",
            benchmark=lambda wildcards: wildcards.benchmark,
            machine=lambda wildcards: wildcards.machine,
            simulation=lambda wildcards: config["benchmarks"][wildcards.benchmark][
                wildcards.machine
            ].keys(),
            repeat=range(5),
        ),
    output:
        output="specfempp_workdir/{benchmark}/{machine}/results.csv",
    localrule: True
    shell:
        """
            echo "nxmax,nzmax,repeat,solver_time,hostname" > {output} && \
            for file in {input.profile_files}; do \
                cat $file >> {output}; \
            done
        """


rule specfempp_clean:
    localrule: True
    shell:
        """
            rm -rf specfempp_workdir
        """

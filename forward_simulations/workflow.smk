
configfile: "config.yaml"


rule all:
    input:
        [
            "workdir/{benchmark}/{machine}/{simulation}/repeat_{repeat}/seismograms".format(
                benchmark=benchmark,
                machine=machine,
                simulation=simulation,
                repeat=repeat,
            )
            for benchmark in config["benchmarks"].keys()
            for machine in config["benchmarks"][benchmark].keys()
            for simulation in config["benchmarks"][benchmark][machine].keys()
            for repeat in range(5)
        ],
    localrule: True


rule mesh_par_file:
    input:
        par_file="templates/{benchmark}/SPECFEMPP/Par_File",
        interfaces="templates/{benchmark}/SPECFEMPP/topography.dat",
    output:
        par_file="workdir/{benchmark}/{machine}/{simulation}/mesh/mesh.par",
        interfaces="workdir/{benchmark}/{machine}/{simulation}/mesh/topography.dat",
    params:
        mesh_output_folder="workdir/{benchmark}/{machine}/{simulation}/mesh/OUTPUT_FILES",
        nx=lambda wildcards: config["benchmarks"][wildcards.benchmark][
            wildcards.machine
        ][wildcards.simulation]["nx"],
        nz=lambda wildcards: config["benchmarks"][wildcards.benchmark][
            wildcards.machine
        ][wildcards.simulation]["nz"],
    localrule: True
    run:
        with open(input.par_file) as f:
            template = f.read()

        content = template.format(
            output_folder=params.mesh_output_folder,
            interfacesfile=output.interfaces,
            nxmax=params.nx,
            nzmax=params.nz,
        )

        with open(output.par_file, "w") as f:
            f.write(content)

        with open(input.interfaces, "r") as f:
            template = f.read()

        content = template.format(nzmax=params.nz)

        with open(output.interfaces, "w") as f:
            f.write(content)


rule mesh:
    input:
        meshfem_bin=config["build_dir"]["specfempp"] + "/xmeshfem2D",
        par_file="workdir/{benchmark}/{machine}/{simulation}/mesh/mesh.par",
    output:
        mesh="workdir/{benchmark}/{machine}/{simulation}/mesh/OUTPUT_FILES/database.bin",
        stations="workdir/{benchmark}/{machine}/{simulation}/mesh/OUTPUT_FILES/STATIONS",
    localrule: True
    shell:
        """
            module purge
            {input.meshfem_bin} -p {input.par_file}
        """


rule specfem_config:
    input:
        specfem_config="templates/{benchmark}/SPECFEMPP/specfem_config.yaml.in",
        sources="templates/{benchmark}/SPECFEMPP/sources.yaml.in",
    output:
        specfem_config="workdir/{benchmark}/{machine}/{simulation}/{repeat}/specfem_config.yaml",
        sources="workdir/{benchmark}/{machine}/{simulation}/{repeat}/sources.yaml",
    params:
        mesh_database="workdir/{benchmark}/{machine}/{simulation}/mesh/OUTPUT_FILES/database.bin",
        stations_file="workdir/{benchmark}/{machine}/{simulation}/mesh/OUTPUT_FILES/STATIONS",
        work_directory="workdir/{benchmark}/{machine}/{simulation}/{repeat}/",
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


rule solver:
    input:
        solver_bin=config["build_dir"]["specfempp"] + "/specfem2d",
        specfem_config="workdir/{benchmark}/{machine}/{simulation}/{repeat}/specfem_config.yaml",
        sources="workdir/{benchmark}/{machine}/{simulation}/{repeat}/sources.yaml",
        mesh_database="workdir/{benchmark}/{machine}/{simulation}/mesh/OUTPUT_FILES/database.bin",
        stations_file="workdir/{benchmark}/{machine}/{simulation}/mesh/OUTPUT_FILES/STATIONS",
    output:
        seismograms=directory(
            "workdir/{benchmark}/{machine}/{simulation}/{repeat}/seismograms"
        ),
    params:
        work_directory="workdir/{benchmark}/{machine}/{simulation}/{repeat}",
    resources:
        nodes=lambda wildcards: config["resources"][wildcards.machine]["nodes"],
        tasks=lambda wildcards: config["resources"][wildcards.machine]["tasks"],
        cpus_per_task=lambda wildcards: config["resources"][wildcards.machine][
            "cpus_per_task"
        ],
        runtime=lambda wildcards: config["resources"][wildcards.machine]["runtime"],
        constraint=lambda wildcards: config["resources"][wildcards.machine]["constraint"],
        slurm_extra=lambda wildcards: config["resources"][wildcards.machine][
            "slurm_extra"
        ],
    shell:
        """
            module purge
            module load boost/1.73.0
            mkdir -p {params.work_directory}/seismograms

            {input.solver_bin} -p {input.specfem_config}
        """


rule clean:
    localrule: True
    shell:
        """
            rm -rf workdir
        """


configfile: "config.yaml"


rule specfem2d_all:
    input:
        profile=expand(
            "specfem2d_workdir/{benchmark}/{machine}/results.csv",
            benchmark=config["benchmarks"].keys(),
            machine=config["resources"].keys(),
        ),
    localrule: True


rule specfem2d_set_up:
    input:
        par_file="templates/{benchmark}/SPECFEM2D/Par_file",
        interfaces="templates/{benchmark}/SPECFEM2D/topography.dat",
        source_files="templates/{benchmark}/SPECFEM2D/SOURCE",
    output:
        par_file="specfem2d_workdir/{benchmark}/{machine}/{simulation}/{repeat}/DATA/Par_file",
        interfaces="specfem2d_workdir/{benchmark}/{machine}/{simulation}/{repeat}/DATA/topography.dat",
        source_files="specfem2d_workdir/{benchmark}/{machine}/{simulation}/{repeat}/DATA/SOURCE",
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

        content = template.format(**format_dict, interfacesfile=output.interfaces)

        with open(output.par_file, "w") as f:
            f.write(content)

        with open(input.interfaces, "r") as f:
            template = f.read()

        content = template.format(**format_dict)

        with open(output.interfaces, "w") as f:
            f.write(content)

        shutil.copy(input.source_files, output.source_files)


rule specfem2d_link_executibles:
    input:
        specfem_exec=config["build_dir"]["specfem2d"] + "/bin/xspecfem2D",
        meshfem_exec=config["build_dir"]["specfem2d"] + "/bin/xmeshfem2D",
    output:
        specfem_exec="specfem2d_workdir/{benchmark}/{machine}/{simulation}/{repeat}/bin/xspecfem2D",
        meshfem_exec="specfem2d_workdir/{benchmark}/{machine}/{simulation}/{repeat}/bin/xmeshfem2D",
    localrule: True
    shell:
        """
            ln -s {input.specfem_exec} {output.specfem_exec}
            ln -s {input.meshfem_exec} {output.meshfem_exec}
        """


rule specfem2d_mesh:
    input:
        meshfem_bin="specfem2d_workdir/{benchmark}/{machine}/{simulation}/{repeat}/bin/xmeshfem2D",
        par_file="specfem2d_workdir/{benchmark}/{machine}/{simulation}/{repeat}/DATA/Par_file",
    output:
        mesh="specfem2d_workdir/{benchmark}/{machine}/{simulation}/{repeat}/OUTPUT_FILES/Database00000.bin",
        stations="specfem2d_workdir/{benchmark}/{machine}/{simulation}/{repeat}/DATA/STATIONS",
    localrule: True
    shell:
        """
            module purge
            module load intel-mpi/gcc/2019.7

            cd specfem2d_workdir/{wildcards.benchmark}/{wildcards.machine}/{wildcards.simulation}/{wildcards.repeat}/
            mkdir -p OUTPUT_FILES
            ./bin/xmeshfem2D
        """


rule specfem2d_forward_simulation:
    input:
        specfem_exec="specfem2d_workdir/{benchmark}/{machine}/{simulation}/{repeat}/bin/xspecfem2D",
        mesh="specfem2d_workdir/{benchmark}/{machine}/{simulation}/{repeat}/OUTPUT_FILES/Database00000.bin",
        stations="specfem2d_workdir/{benchmark}/{machine}/{simulation}/{repeat}/DATA/STATIONS",
    output:
        log="specfem2d_workdir/{benchmark}/{machine}/{simulation}/{repeat}/output.log",
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
            module load intel-mpi/gcc/2019.7

            cd specfem2d_workdir/{wildcards.benchmark}/{wildcards.machine}/{wildcards.simulation}/{wildcards.repeat}/
            echo "Hostname: $(hostname)" > output.log
            ./bin/xspecfem2D >> output.log
        """


rule specfem2d_generate_profile:
    input:
        log="specfem2d_workdir/{benchmark}/{machine}/{simulation}/{repeat}/output.log",
    output:
        profile="specfem2d_workdir/{benchmark}/{machine}/{simulation}/{repeat}/profile.csv",
    params:
        nxmax=lambda wildcards: config["benchmarks"][wildcards.benchmark][
            wildcards.machine
        ][wildcards.simulation]["nx"][-1],
        nzmax=lambda wildcards: config["benchmarks"][wildcards.benchmark][
            wildcards.machine
        ][wildcards.simulation]["nz"][-1],
        repeat=lambda wildcards: wildcards.repeat,
    localrule: True
    shell:
        """
            SOLVER_TIME=$(grep "Total duration of the time loop in seconds" {input.log} | awk '{{print $10}}') && \
            HOSTNAME=$(grep "Hostname" {input.log} | awk '{{print $2}}') && \
            echo "{params.nxmax},{params.nzmax},{params.repeat},$SOLVER_TIME,$HOSTNAME" > {output.profile}
        """


rule specfem2d_compile_results:
    input:
        ## use work_directories function to get list of work directories
        profile_files=expand(
            "specfem2d_workdir/{benchmark}/{machine}/{simulation}/repeat_{repeat}/profile.csv",
            benchmark=lambda wildcards: wildcards.benchmark,
            machine=lambda wildcards: wildcards.machine,
            simulation=lambda wildcards: config["benchmarks"][wildcards.benchmark][
                wildcards.machine
            ].keys(),
            repeat=range(5),
        ),
    output:
        output="specfem2d_workdir/{benchmark}/{machine}/results.csv",
    localrule: True
    shell:
        """
            echo "nxmax,nzmax,repeat,solver_time,hostname" > {output} && \
            for file in {input.profile_files}; do \
                cat $file >> {output}; \
            done
        """


rule specfem2d_clean:
    localrule: True
    shell:
        """
            rm -rf specfem2d_workdir
        """

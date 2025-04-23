#!/bin/bash

#SBATCH --job-name=cpu_benchmarks
#SBATCH --output=cpu_benchmarks_output.txt
#SBATCH --error=cpu_benchmarks_error.txt
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --constraint="intel|cascade"
#SBATCH --time=01:00:00

source .venv/bin/activate  # Activate the virtual environment

cd forward_simulations # Change to the directory containing the script

benchmarks=$1  # Get the first argument passed to the script
if [ -z "$benchmarks" ]; then
    echo "Usage: $0 <benchmarks>"
    exit 1
fi
# Check if the benchmarks argument is provided
echo "Running benchmarks: $benchmarks"

snakemake results-${benchmarks}-cpu.csv results-${benchmarks}-cpu.png -j 1 --rerun-incomplete # Run Snakemake with 1 job to ensure it uses a single CPU core
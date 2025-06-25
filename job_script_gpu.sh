#!/bin/bash

#SBATCH --job-name=gpu_benchmarks
#SBATCH --output=gpu_benchmarks_output.txt
#SBATCH --error=gpu_benchmarks_error.txt
#SBATCH --ntasks=1
#SBATCH --nodes=1
#SBATCH --cpus-per-task=10
#SBATCH --mem-per-cpu=40000
#SBATCH --time=01:00:00
#SBATCH --gres=gpu:1  # Request a GPU resource

source .venv/bin/activate  # Activate the virtual environment

cd forward_simulations # Change to the directory containing the script

benchmarks=$1  # Get the first argument passed to the script
if [ -z "$benchmarks" ]; then
    echo "Usage: $0 <benchmarks>"
    exit 1
fi
# Check if the benchmarks argument is provided
echo "Running benchmarks: $benchmarks"

snakemake results-${benchmarks}-gpu.csv results-${benchmarks}-gpu.png -j 1 --rerun-incomplete # Run Snakemake with 1 job to ensure it uses a single CPU core
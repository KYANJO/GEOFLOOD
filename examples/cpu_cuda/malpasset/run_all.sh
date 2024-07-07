#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status.

# Function to generate and submit jobs
generate_and_submit() {
  MPI_NUM_TASKS=$1
  USER_CUDA=$2
  IS_GPU=$3
  JOB_NAME="Malpasset$MPI_NUM_TASKS"
  JOB_TYPE=$( $IS_GPU && echo "cuda" || echo "cpu" )
  OUTPUT_NAME="gflood_${JOB_TYPE}${MPI_NUM_TASKS}"
  QUEUE_PARTITION=$( $IS_GPU && echo "gpu" || echo "bsudfq" )
  GPU_RESOURCE=$( $IS_GPU && echo "#SBATCH --gres=gpu:L40:1" || echo "" )

  # Creating a temporary run script for the current number of MPI tasks
  cat > "temp_run_${MPI_NUM_TASKS}.sh" <<EOF
#!/bin/bash
#SBATCH --time=100:30:00
#SBATCH -n ${MPI_NUM_TASKS}  # MPI processes
#SBATCH -N 1                # Total number of nodes
#SBATCH --job-name=${JOB_NAME}
#SBATCH --output=${OUTPUT_NAME}.o%j
${GPU_RESOURCE}
#SBATCH --exclusive
#SBATCH -p ${QUEUE_PARTITION}  # Queue (partition)
module load slurm
module load mpi
mpirun -np ${MPI_NUM_TASKS} ./malpasset_cpucuda -F geoflood.ini --user:cuda=${USER_CUDA}
EOF

  # Submit the job
  sbatch "temp_run_${MPI_NUM_TASKS}.sh"
}

# Loop over the desired MPI tasks for GPU and CPU jobs
# GPU jobs
for n in 4 2 1; do
  generate_and_submit "$n" true true
done

sleep 0.5

# CPU jobs
for n in 64 48 32 24 16 8 4 2 1; do
  generate_and_submit "$n" false true
done

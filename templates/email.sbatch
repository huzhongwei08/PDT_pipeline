#!/bin/bash
#SBATCH -J JOBNAME_email
#SBATCH -o JOBNAME.out
#SBATCH -e JOBNAME.err
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --reservation=lopez_amd
#SBATCH --partition=reservation
#SBATCH --dependency=afterany:JOBID
#SBATCH --mail-user=EMAIL
#SBATCH --mail-type=END
#SBATCH --parsable

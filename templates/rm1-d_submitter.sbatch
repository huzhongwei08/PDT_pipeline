#!/bin/bash
#SBATCH -J RM1-D_submitter
#SBATCH -o RM1-D_submitter.o
#SBATCH -e RM1-D_submitter.e
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --partition=short
#SBATCH --constraint=ib
#SBATCH --time=24:00:00
#SBATCH --parsable
#SBATCH --dependency=afterany:PM7_ID

# source config and function files
source_config

gen_slurm_report

# submits RM1-D array after PM7 array is complete
cd $RM1_D
RM1_ID=$(submit_array "$TITLE\_RM1-D" "gamess_inp.txt" "inp" $FLOW_TOOLS/templates/array_gamess_rm1-d.sbatch $DFT_TIME)
wait

# submits SP-DFT submitter which submits SP-DFT array after RM1-D array is complete
sed "s/RM1_ID/$RM1_ID/g" $FLOW_TOOLS/templates/sp-dft_submitter.sbatch | sbatch

#!/bin/bash
#SBATCH -J DFT-OPT-S0-VAC_submitter
#SBATCH -o DFT-OPT-S0-VAC_submitter.o
#SBATCH -e DFT-OPT-S0-VAC_submitter.e
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --partition=lopez
#SBATCH --constraint=ib
#SBATCH --time=24:00:00
#SBATCH --parsable
#SBATCH --dependency=afterany:RM1_ID

# source config and function files
source_config

gen_slurm_report

# submit S0 DFT optimization array (in vacuo)
cd $S0_VAC
DFT_OPT_S0_VAC_ID=$(submit_array "$TITLE\_S0_VAC" "g16_inp.txt" "com" $FLOW_TOOLS/templates/array_g16_dft-opt-s0-vac.sbatch $DFT_TIME)
wait

# submits SP-DFT submitter which submits SP-DFT array after DFT-OPT-S0-VAC array is complete
sed "s/DFT_OPT_S0_VAC_ID/$DFT_OPT_S0_VAC_ID/g" $FLOW_TOOLS/templates/sp-dft_submitter.sbatch | sbatch

#!/bin/bash
#SBATCH -J S0-DFT-OPT-SOLV_submitter
#SBATCH -o S0-DFT-OPT-SOLV_submitter.o
#SBATCH -e S0-DFT-OPT-SOLV_submitter.e
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --partition=short
#SBATCH --constraint=ib
#SBATCH --time=24:00:00
#SBATCH --parsable
#SBATCH --dependency=afterany:RM1_ID

# source config and function files
source_config

gen_slurm_report

# submit S0-DFT-OPT-SOLV array in solvent (water for PDT)
cd $S0_DFT_OPT_SOLV
S0_DFT_OPT_SOLV_ID=$(submit_array "$TITLE\_S0_DFT_OPT_SOLV" "g16_inp.txt" "com" $FLOW_TOOLS/templates/array_g16_s0-dft-opt-solv.sbatch $DFT_TIME)

# submits SP-DFT-SOLV submitter which submits SP-DFT-SOLV array after S0-DFT-OPT-SOLV array is complete
sed "s/S0_DFT_OPT_SOLV_ID/$S0_DFT_OPT_SOLV_ID/g" $FLOW_TOOLS/templates/sp-dft-solv_submitter.sbatch | sbatch

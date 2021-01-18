#!/bin/bash
#SBATCH -J SP-DFT_SOLV_submitter
#SBATCH -o SP-DFT_SOLV_submitter.o
#SBATCH -e SP-DFT_SOLV_submitter.e
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --partition=short
#SBATCH --constraint=ib
#SBATCH --time=24:00:00
#SBATCH --parsable
#SBATCH --dependency=afterany:S0_DFT_OPT_VAC_ID

# source config and function files
source_config

# this sbatch script does not run until the completion of the S0_DFT_OPT_VAC array
# Z. Hu, 01/12/2021, do single point DFT in solvent using B3LYP
cd $SP_DFT/solv
SP_DFT_SOLV_ID=$(submit_array "$TITLE\_SP-DFT-solv" "g16_inp.txt" "com" $FLOW_TOOLS/templates/array_g16_sp-dft-solv.sbatch $DFT_TIME)


# submits MO_OVERLAP submitter which submits MO_OVERLAP tasks after SP_DFT_SOLV array is complete
# Z. Hu, 01/12/2021, do molecular orbital overlap using Gaussian cubs
cd $MO_OVERLAP
sed "s/SP_DFT_SOLV_ID/$SP_DFT_SOLV_ID/g" $FLOW_TOOLS/templates/mo_overlap_submitter.sbatch | sbatch

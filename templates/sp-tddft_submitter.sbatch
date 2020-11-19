#!/bin/bash
#SBATCH -J SP-TDDFT_submitter
#SBATCH -o SP-TDDFT_submitter.o
#SBATCH -e SP-TDDFT_submitter.e
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
# submits SP-TDDFT array after S0_DFT_OPT_VAC array is complete
cd $SP_TDDFT
SP_TDDFT_ID=$(submit_array "$TITLE\_SP-TDDFT" "g16_inp.txt" "com" $FLOW_TOOLS/templates/array_g16_sp_td-dft.sbatch $DFT_TIME)
wait

# submits PYSOC submitter which submits PYSOC array after SP-TDDFT array is complete
sed "s/SP_TDDFT_ID/$SP_TDDFT_ID/g" $FLOW_TOOLS/templates/soc_submitter.sbatch | sbatch

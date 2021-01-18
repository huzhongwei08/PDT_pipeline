#!/bin/bash
#SBATCH -J SP-TDDFT_wB97XD_submitter
#SBATCH -o SP-TDDFT_wB97XD_submitter.o
#SBATCH -e SP-TDDFT_wB97XD_submitter.e
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
# Z. Hu, 12/12/2020, do both B3LYP and wB97XD
#Z. Hu, 01/12/2021, do wB97XD as the extra one
# wB97XD
cd $SP_TDDFT/wb97xd
SP_TDDFT_wB97XD_ID=$(submit_array "$TITLE\_SP-TDDFT" "g16_inp.txt" "com" $FLOW_TOOLS/templates/array_g16_sp_td-dft.sbatch $DFT_TIME)
wait

# submits PYSOC wB97XD submitter which submits PYSOC jobs after SP-TDDFT_wB97XD array is complete
# Z. Hu, 01/12/2021, note that the extra one is for wB97XD
cd $SOC
sed "s/SP_TDDFT_wB97XD_ID/$SP_TDDFT_wB97XD_ID/g" $FLOW_TOOLS/templates/soc-wb97xd_submitter.sbatch | sbatch

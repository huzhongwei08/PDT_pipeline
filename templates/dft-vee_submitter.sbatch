#!/bin/bash
#SBATCH -J DFT-VEE_submitter
#SBATCH -o DFT-VEE_submitter.o
#SBATCH -e DFT-VEE_submitter.e
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --partition=short
#SBATCH --constraint=ib
#SBATCH --time=24:00:00
#SBATCH --parsable
#SBATCH --dependency=afterany:LEE_ID

# source config and function files
source_config

gen_slurm_report

# Z. Hu, this sbatch script does not run until the completion of the LEE array
# submits single-point TDDFT B3LYP and wB97XD arrays
# B3LYP
cd $SP_TDDFT/b3lyp
SP_TDDFT_B3LYP_ID=$(submit_array "$TITLE\_SP-TDDFT-B3LYP" "g16_inp.txt" "com" $FLOW_TOOLS/templates/array_g16_sp-tddft-solv.sbatch $DFT_TIME)
# wB97XD
cd $SP_TDDFT/wb97xd
SP_TDDFT_wB97XD_ID=$(submit_array "$TITLE\_SP-TDDFT-wB97XD" "g16_inp.txt" "com" $FLOW_TOOLS/templates/array_g16_sp-tddft-solv.sbatch $DFT_TIME)

# submits PYSOC B3LYP and wB97XD submitters which submit PYSOC jobs after SP-TDDFT-B3LYP/wB97XD arrays are complete
cd $SOC
# B3LYP
sed "s/SP_TDDFT_B3LYP_ID/$SP_TDDFT_B3LYP_ID/g" $FLOW_TOOLS/templates/soc-b3lyp_submitter.sbatch | sbatch
# wB97XD
sed "s/SP_TDDFT_wB97XD_ID/$SP_TDDFT_wB97XD_ID/g" $FLOW_TOOLS/templates/soc-wb97xd_submitter.sbatch | sbatch

# submits MO_OVERLAP submitter which submits MO_OVERLAP tasks
cd $MO_OVERLAP
sbatch $FLOW_TOOLS/templates/mo_overlap_submitter.sbatch

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
# submit S0 DFT optimization array (in vacuo)
cd $S0_VAC
S0_DFT_OPT_VAC_ID=$(submit_array "$TITLE\_S0_VAC" "g16_inp.txt" "com" $FLOW_TOOLS/templates/array_g16_s0_dft-opt_vac.sbatch $DFT_TIME)
wait

# Z. Hu, PDT, submit single-point TD-DFT submitter
cd $MAIN_DIR
sed "s/S0_DFT_OPT_VAC_ID/$S0_DFT_OPT_VAC_ID/g" $FLOW_TOOLS/templates/sp-tddft_submitter.sbatch | sbatch

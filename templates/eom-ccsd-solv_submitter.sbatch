#!/bin/bash
#SBATCH -J EOM-CCSD_SOLV_submitter
#SBATCH -o EOM-CCSD_SOLV_submitter.o
#SBATCH -e EOM-CCSD_SOLV_submitter.e
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
# Z. Hu, 01/14/2021, do equation-of-motion coupled cluster-single double in solvent
cd $EOM_CCSD
submit_array "$TITLE\_EOM-CCSD-solv" "g16_inp.txt" "com" $FLOW_TOOLS/templates/array_g16_eom-ccsd-solv.sbatch $DFT_TIME

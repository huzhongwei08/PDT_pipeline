#!/bin/bash
#SBATCH -J SP-DFT-SOLV_submitter
#SBATCH -o SP-DFT-SOLV_submitter.o
#SBATCH -e SP-DFT-SOLV_submitter.e
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --partition=short
#SBATCH --constraint=ib
#SBATCH --time=24:00:00
#SBATCH --parsable
#SBATCH --dependency=afterany:S0_DFT_OPT_SOLV_ID

# source config and function files
source_config

# this sbatch script does not run until the completion of the S0-DFT-OPT-SOLV array
# Z. Hu, 01/12/2021, do single point DFT in solvent using B3LYP
# Z. Hu, 03/27/2021, use the folder name "SP_DFT_SOLV"
cd $SP_DFT_SOLV
SP_DFT_SOLV_ID=$(submit_array "$TITLE\_SP-DFT-solv" "g16_inp.txt" "com" $FLOW_TOOLS/templates/array_g16_sp-dft-solv.sbatch $DFT_TIME)
wait

# submits least-energy-extractor to find the conformers with the lowest energy
LEE_ID=$(sed "s/SP_DFT_SOLV_ID/$SP_DFT_SOLV_ID/" $FLOW_TOOLS/templates/least-energy-extractor.sbatch | sed "s/EMAIL/$DEFAULT_EMAIL/" | sbatch)
wait

# submit VEE submitter that submits MO_OVERLAP and SP-TDDFT with two different XC functionals
sed "s/LEE_ID/$LEE_ID/g" $FLOW_TOOLS/templates/dft-vee_submitter.sbatch | sbatch

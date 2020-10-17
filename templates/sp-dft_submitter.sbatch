#!/bin/bash
#SBATCH -J SP-DFT_submitter
#SBATCH -o SP-DFT_submitter.o
#SBATCH -e SP-DFT_submitter.e
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --partition=lopez
#SBATCH --constraint=ib
#SBATCH --time=24:00:00
#SBATCH --parsable
#SBATCH --dependency=afterany:RM1_ID

# source config and function files
source_config

# this sbatch script does not run until the completion of the RM1-D array
# submits SP-DFT array after RM1-D array is complete
cd $SP_DFT
SP_DFT_ID=$(submit_array "$TITLE\_SP-DFT" "g16_inp.txt" "com" $FLOW_TOOLS/templates/array_g16_sp-dft.sbatch $DFT_TIME)
wait

# submits least-energy-extractor to find the conformers with the lowest energy
LEE_ID=$(sed "s/SP_DFT_ID/$SP_DFT_ID/" $FLOW_TOOLS/templates/least-energy-extractor.sbatch | sed "s/EMAIL/$DEFAULT_EMAIL/" | sbatch)
wait

# submit VEE and S0 DFT optimization submitter
cd $MAIN_DIR
sed "s/LEE_ID/$LEE_ID/g" $FLOW_TOOLS/templates/dft-vee_submitter.sbatch | sbatch

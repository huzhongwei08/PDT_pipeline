#!/bin/bash
#SBATCH -J DFT-OPT_submitter
#SBATCH -o DFT-OPT_submitter.o
#SBATCH -e DFT-OPT_submitter.e
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --partition=lopez
#SBATCH --constraint=ib
#SBATCH --time=24:00:00
#SBATCH --parsable
#SBATCH --dependency=afterany:S0_DFT_OPT_VAC_ID

# source config and function files
source_config

gen_slurm_report

# This script runs after the completion of the DFT S0 optimization (in vacuo)

# handles submission of the following DFT optimizations:
#	- S0 (in solvent)
#	- SN (in solvent)
#	- T1 (in solvent)
#	- anion radical (in solvent)
# 	- cation radical (in vacuo)

# submit S0 DFT optimization array (in solvent)
cd $S0_SOLV
S0_DFT_OPT_SOLV_ID=$(submit_array "$TITLE\_S0_SOLV" g16_inp.txt com $FLOW_TOOLS/templates/array_g16_dft-opt.sbatch $DFT_TIME)
wait

# submit SN DFT optimization array (in solv)
cd $SN_SOLV
SN_DFT_OPT_SOLV_ID=$(submit_array "$TITLE\_SN_SOLV" g16_inp.txt com $FLOW_TOOLS/templates/array_g16_dft-opt.sbatch $DFT_TIME)
wait

# submit T1 DFT optimization array (in solvent)
cd $T1_SOLV
T1_DFT_OPT_SOLV_ID=$(submit_array "$TITLE\_T1_SOLV" g16_inp.txt com $FLOW_TOOLS/templates/array_g16_dft-opt.sbatch $DFT_TIME)
wait

# submit cation radical optimization array (in solvent)
cd $CAT_RAD_SOLV
CAT_RAD_DFT_OPT_SOLV_ID=$(submit_array "$TITLE\_CAT-RAD_SOLV" g16_inp.txt com $FLOW_TOOLS/templates/array_g16_dft-opt.sbatch $DFT_TIME)
wait

# submit cation radical optimization array (in vacuo)
cd $CAT_RAD_VAC
CAT_RAD_DFT_OPT_VAC_ID=$(submit_array "$TITLE\_CAT-RAD_VAC" g16_inp.txt com $FLOW_TOOLS/templates/array_g16_dft-opt.sbatch $DFT_TIME)
wait

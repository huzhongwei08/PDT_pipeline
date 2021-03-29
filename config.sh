#!/bin/bash

# workflow version
# updated 
FLOW_VERSION=1.0

# directory variables for quick cd
export MAIN_DIR=$(readlink -e .)
export ALL_LOGS=$(readlink -e all-logs)
export CAT_RAD_VAC=$(readlink -e cat-rad_vac)
export CAT_RAD_SOLV=$(readlink -e cat-rad_solv)
export FLOW_TOOLS=$(readlink -e flow-tools)
export MOL_DATA=$(readlink -e mol-data)
export PM7=$(readlink -e pm7)
export RM1_D=$(readlink -e rm1-d)
export S0_SOLV=$(readlink -e s0_solv)
export S0_DFT_OPT_SOLV=$(readlink -e s0-dft-opt-solv)
export S0_VAC=$(readlink -e s0_vac)
export SN_SOLV=$(readlink -e sn_solv)
export SP_DFT=$(readlink -e sp-dft)
export SP_DFT_SOLV=$(readlink -e sp-dft-solv)
export SP_TDDFT=$(readlink -e sp-tddft)
export T1_SOLV=$(readlink -e t1_solv)
export T1_SP_TDDFT=$(readlink -e t1_sp-tddft)
export UNOPT_PDBS=$(readlink -e unopt_pdbs)
# -----------------------------------
# Z. Hu, spin-orbital coupling folder
export SOC=$(readlink -e soc)
# -----------------------------------
# -----------------------------------------
# Z. Hu, molecular orbital overlap
export MO_OVERLAP=$(readlink -e mo_overlap)
# -----------------------------------------
# -----------------------------------------
# Z. Hu, molecular orbital overlap
export EOM_CCSD=$(readlink -e eom_ccsd)
# -----------------------------------------

# useful variables
export DEFAULT_EMAIL="$USER@husky.neu.edu"
export DEFAULT_PARTITION=$(sinfo | awk -vcol=PARTITION '(NR==1){colnum=-1;for(i=1;i<=NF;i++)if($(i)==col)colnum=i;}{print $(colnum)}' | grep '*' | uniq | sed "s|*||")
export DEFAULT_SIMULTANEOUS_JOBS=50
export DFT_TIME=1340m
export PM7_TIME=140m
export TITLE=$(basename $MAIN_DIR)

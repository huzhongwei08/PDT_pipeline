#!/bin/bash
#SBATCH -J JOBNAME
#SBATCH -o %A_%a.o				
#SBATCH -e %A_%a.e				
#SBATCH -N 1			
#SBATCH -n 16               			
#SBATCH --partition=short
#SBATCH --constraint=ib
#SBATCH --time=24:00:00
#SBATCH --array=1-TOTAL%50 			
#SBATCH --parsable

# array sbatch script for S0 DFT optimization in vacuo

# source config and function files
source_config

gen_slurm_report

#input file to be processed
input_file=$(fetch_input $SLURM_ARRAY_TASK_ID g16_inp.txt)

#name of molecule and out/err files
title="${input_file/.com/}"
inchi_key="${input_file/_S0_vac.com/}"
log=$title.log

# check if job is already complete
completed=$(job_finished $log)

# run job if incomplete
if [[ $completed -eq 0 ]]; then
    # execute job
    timeout TIME time g16 $input_file
    timeout_status=$?

    # rename .o and .e files
    rename_slurm_outputs $SLURM_ARRAY_TASK_ID $title

    # termination status (opt successful if termination=1, opt & freq successful if termination=2)
    termination=$(grep 'Normal termination' $log | wc -l)
else
    # job is already coplete
    timeout_status=0
    termination=1
fi

# end of job preparation for next submissions
if [ $timeout_status -eq 124 ]; then		# if the run times out
    # move files to timeouts directory
    mv $title* $S0_VAC/resubmits/
    cd $S0_VAC/resubmits/
    
    # submit restart calc
    restart_opt $title $FLOW_TOOLS/templates/s0_dft-opt_vac_g16_sbatch_re.txt
elif [ $termination -eq 1 ]; then		# if the run terminated successfully
    # move files to completed directory
    mv $title* $S0_VAC/completed/
    cd $S0_VAC/completed/
    to_all_logs $log
    
    # make pdb file of DFT optimized S0 (in vacuo) structure
    obabel -i log $log -o pdb -O $inchi_key.pdb &>/dev/null
    mv $inchi_key.pdb $S0_VAC/opt_pdbs/
    
    # -------------------------------------
    # Z. Hu, skip vibrational freq for now
    ## set up and submit freq calc
    #setup_freq $log
    # -------------------------------------
    
    # -----------------------------------------------------------------------------
    # Z. Hu, obtain the charge for the PDB file
    filename=$(basename $inchi_key.pdb)
    CHARGE_PDB=$(python $FLOW_TOOLS/scripts/charge_from_pdb_each.py $UNOPT_PDBS/${filename:0:27}_0.pdb)
    # -----------------------------------------------------------------------------
    # -----------------------------------------------------------------------------------------------------
    # Z. Hu, do 5 singlet and 5 triplet excited states, use new functionals wB97XD and water as the solvent
    #        include keywords "6D 10F nosymm FGInput" for PySOC simulations after the SP-TDDFT step
    #        ave the *rwf but not the *chk file for PySOC simulations (might need to rm as it is huge)
    # Z. Hu, 11/24/2020, switch to B3LYP as no experimental calibration
    cd $S0_VAC/opt_pdbs/
    # Z. Hu, 12/12/2020, do both B3LYP and wB97XD
    # B3LYP
    bash $FLOW_TOOLS/scripts/make-com.sh -i=$inchi_key.pdb -r='#p B3LYP/6-31+G(d,p) td=(NStates=5, 50-50) SCRF=(Solvent=Water) 6D 10F nosymm GFInput' -c=$CHARGE_PDB -ns='CHK' -t=$title\_sp-tddft-b3lyp -l=$SP_TDDFT/b3lyp 
    # wB97XD
    bash $FLOW_TOOLS/scripts/make-com.sh -i=$inchi_key.pdb -r='#p wB97XD/6-31+G(d,p) td=(NStates=5, 50-50) SCRF=(Solvent=Water) 6D 10F nosymm GFInput' -c=$CHARGE_PDB -ns='CHK' -t=$title\_sp-tddft-wb97xd -l=$SP_TDDFT/wb97xd 
    # Z. Hu, 01/12/2020, do single point DFT in solvent for orbital overlap comparison
    bash $FLOW_TOOLS/scripts/make-com.sh -i=$inchi_key.pdb -r='#p B3LYP/6-31+G(d,p) SCRF=(Solvent=Water)' -c=$CHARGE_PDB -ns='RWF' -t=$title\_sp-dft-solv -l=$SP_DFT/solv 
    # Z. Hu, 01/14/2020, do equation-of-motion coupled cluster single-double in solvent for negative S1-T1 gap
    bash $FLOW_TOOLS/scripts/make-com.sh -i=$inchi_key.pdb -r='#p EOMCCSD(NStates=10,EnergyOnly,Singlets,Triplets)/6-31+G(d,p) SCRF=(Solvent=Water)' -c=$CHARGE_PDB -t=$title\_eom-ccsd-solv -l=$EOM_CCSD 
    # -----------------------------------------------------------------------------------------------------
    
    exit 0
else
    # move files to failed_opt directory
    mv $title* failed_opt/
    exit 1
fi

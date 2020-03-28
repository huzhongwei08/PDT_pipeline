#!/bin/bash
#SBATCH -J JOBNAME			
#SBATCH -o %A_%a.o
#SBATCH -e %A_%a.e	
#SBATCH -N 1
#SBATCH -n 14
#SBATCH --partition=lopez
#SBATCH --constraint=ib
#SBATCH --time=24:00:00
#SBATCH --array=1-TOTAL%50
#SBATCH --parsable

# source config and function files
source_config

gen_slurm_report

#input file to be processed
input_file=$(fetch_input $SLURM_ARRAY_TASK_ID g16_inp.txt)

#name of molecule and out/err files
title="${input_file/.com/}"
log=$title.log

# check if job is already complete or failed
completed=$(job_finished $log)
failed=$(job_failed $log "failed")

# run job if incomplete
if [[ $completed -eq 0 ]]; then
	if [[ $failed -eq 1 ]]; then
		bash $FLOW_TOOLS/scripts/make-com.sh -i="failed/$log" -r='#p pm7 opt=(recalcfc=4)' -f
	fi
    # execute job
    timeout TIME time g16 $input_file
    timeout_status=$?

    # rename .o and .e files
    rename_slurm_outputs $SLURM_ARRAY_TASK_ID $title

	# termination status (successful if termination=1)
	termination=$(grep 'Normal termination' $log | wc -l)
	convergence_fail=$(grep 'Convergence failure' $log | wc -l)
else
	# job already complete
	termination=1
	convergence_fail=0
    timeout_status=0
fi

# handle successful job completion
function fin_handler {
	title=$1	

	# move files to completed directory
	mv $title* $PM7/completed/
	cd $PM7/completed/
 
	# make pdb file of PM7 optimized structure
	obabel -ilog $log -opdb -O $title.pdb &>/dev/null
	mv $title.pdb $PM7/opt_pdbs/
 
	# make GAMESS RM1-D input
	cd $PM7/opt_pdbs/
        # --------------------------------------------
        # Z. Hu, deal with charged molecule for GAMESS
        if [ $CHARGE_PDB != 0 ]
        then
           sed -i '1 c\ $CONTRL RUNTYP=OPTIMIZE ICHARG='$CHARGE_PDB' DFTTYP=NONE EXETYP=RUN MAXIT=200 $END' $FLOW_TOOLS/templates/gamess_rm1d-opt.txt
        fi
        # --------------------------------------------
	bash $FLOW_TOOLS/scripts/pdb2inp.sh $title.pdb $FLOW_TOOLS/templates/gamess_rm1d-opt.txt
	mv $title.inp $RM1_D
}

# end of job preparation for next submissions
if [ $termination -eq 1 ]; then		# if the run terminated successfully
	
	# handle completion
	fin_handler $title
	exit 0

else	
	# setup and submit restart with calcfc
	bash $FLOW_TOOLS/scripts/make-com.sh -i=$log -r='#p pm7 opt=(recalcfc=4)' -f
	time g16 $input_file
	
	termination=$(grep 'Normal termination' $log | wc -l)
	
	if [ $termination -eq 1 ]; then         # if the run terminated successfully
		fin_handler $title
		exit 0
	else
	    # move files to failed directory
    	mv $title* failed/
    	exit 1
	fi	
fi

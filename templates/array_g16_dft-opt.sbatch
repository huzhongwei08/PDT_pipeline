#!/bin/bash
#SBATCH -J JOBNAME	
#SBATCH -o %A_%a.o				
#SBATCH -e %A_%a.e				
#SBATCH -N 1			
#SBATCH -n 16               			
#SBATCH --partition=lopez
#SBATCH --constraint=ib
#SBATCH --time=24:00:00
#SBATCH --array=1-TOTAL%30 			
#SBATCH --parsable

# source config and function files
source_config

gen_slurm_report

#input file to be processed
input_file=$(fetch_input $SLURM_ARRAY_TASK_ID g16_inp.txt)

#name of molecule and out/err files
title="${input_file/.com/}"
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
	convergence_fail=$(grep 'Convergence failure' $log | wc -l)
	link_9999_error=$(grep 'Error termination request processed by link 9999.' $log | wc -l)
else
	timeout_status=0
	termination=1
	convergence_fail=0
fi

# end of job preparation for next submissions
if [ $timeout_status -eq 124 ] || [ $convergence_fail -eq 1 ] || [ $link_9999_error -eq 1 ]; then		# if the run times out or encounters a convergence failure

	# move files to timeouts directory 
	mv $title* resubmits/
	cd resubmits/
	
	# submit restart calc
	restart_opt $title $FLOW_TOOLS/templates/dft-opt_g16_sbatch_re.txt
		
elif [ $termination -eq 1 ]; then		# if the run terminated successfully

	# move files to completed directory
	mv $title* completed/
	cd completed/
	to_all_logs $log
	setup_freq $log
	exit 0

else
	# move files to failed directory
	mv $title* failed_opt/
	exit 1
fi

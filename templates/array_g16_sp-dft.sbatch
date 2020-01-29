#!/bin/bash
#SBATCH -J JOBNAME
#SBATCH -o %A_%a.o
#SBATCH -e %A_%a.e
#SBATCH -N 1
#SBATCH -n 14
#SBATCH -p general
#SBATCH --array=1-TOTAL%50
#SBATCH --parsable

# source config and function files
source_config

gen_slurm_report

#input file to be processed
input_file=$(fetch_input $SLURM_ARRAY_TASK_ID "g16_inp.txt")

#name of molecule and out/err files
title="${input_file/.com/}"
log=$title.log

completed=$(job_finished $log)

# execute job
if [[ $completed -eq 0 ]]; then 
	time g16 $input_file

	# rename .o and .e files
	rename_slurm_outputs $SLURM_ARRAY_TASK_ID $title

	# termination status (successful if termination=1)	
	termination=$(grep 'Normal termination' $log | wc -l)
else
	termination=1
fi

# end of job preparation for next submissions
if [ $termination -ge 1 ]; then		# if the run terminated successfully
	# move files to completed directory
	mv $title* $SP_DFT/completed/
	cd $SP_DFT/completed/ && to-all-logs $log
	exit 0
else					# if the run fails
	# move files to failed directory
	mv $title* $SP_DFT/failed/
	exit 1
fi

#!/bin/bash
#SBATCH -J JOBNAME	
#SBATCH -o %A_%a.o				
#SBATCH -e %A_%a.e				
#SBATCH -N 1			
#SBATCH -n 14               			
#SBATCH --partition=lopez
#SBATCH --constraint="ib"
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

# execute job
time g16 $input_file

# rename .o and .e files
rename_slurm_outputs $SLURM_ARRAY_TASK_ID $title

# termination status (opt successful if termination=1, opt & freq successful if termination=2)
termination=$(grep 'Normal termination' $log | wc -l)

# end of job preparation for next submissions
if [ $termination -eq 1 ]; then		# if the run terminated successfully

	# move files to completed directory
	mv $title* $SP_TDDFT/completed/
	cd $SP_TDDFT/completed/ && to_all_logs $log
	exit 0
else	
	# move files to failed directory
	mv $title* $SP_TDDFT/failed/
	exit 1
fi

#!/bin/bash
#SBATCH -J JOBNAME	
#SBATCH -o JOBNAME.o
#SBATCH -e JOBNAME.e				
#SBATCH -N 1	
#SBATCH -n 14
#SBATCH --partition=lopez
#SBATCH --constraint=ib
#SBATCH --time=24:00:00
#SBATCH --mail-user=EMAIL
#SBATCH --mail-type=END
#SBATCH --parsable

# source config and function files
source_config

gen_slurm_report

#name of molecule and out/err files
title="JOBNAME"
input_file=$title.com
log=$title.log

# execute job
timeout TIME time g16 $input_file
timeout_status=$?

# termination status (opt successful if termination=1, opt & freq successful if termination=2)
termination=$(grep 'Normal termination' $log | wc -l)

# end of job preparation for next submissions
if [ $timeout_status -eq 124 ]; then		# if the run times out

	# submit restart calc
	bash $FLOW_TOOLS/scripts/restart_opt $title $FLOW_TOOLS/templates/dft-opt_g16_sbatch_re.txt
		
elif [ $termination -eq 1 ]; then		# if the run terminated successfully

	# move files to completed directory
	mv $title* ../completed/
	cd ../completed/
	to_all_logs $log
	setup_freq $log
	exit 0

else
	# move files to failed directory
	mv $title* ../failed_opt/
	exit 1
fi

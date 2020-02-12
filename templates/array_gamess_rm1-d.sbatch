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
input_file=$(fetch_input $SLURM_ARRAY_TASK_ID "gamess_inp.txt")

#name of molecule and out/err files
title="${input_file/.inp/}"
out=$title.o

# remove existing scratch files
rm $SCRATCH/gamess_scratch/$title*
rm $SCRATCH/gamess_scratch/scr/$title*


# check if job is already complete
completed=$(job_finished $out)

# run job if incomplete
if [[ $completed -eq 0 ]]; then
    # execute job
	time $FLOW/utils/rungms $input_file

    # rename .o and .e files
    rename_slurm_outputs $SLURM_ARRAY_TASK_ID $title
	
	termination=$(grep 'TERMINATED NORMALLY' $out | wc -l)
else
	termination=1
fi

# end of job preparation for next submissions
if [ $termination -eq 1 ]; then		# if the run terminated successfully

	# move files to completed directory and discard scratch files
	mv $title* $RM1_D/completed/
	rm $SCRATCH/gamess_scratch/scr/$title*
	
	# make pdb file of RM1-D optimized structure
	cd $RM1_D/completed/
	obabel -igam $title.o -opdb -O $title.pdb &>/dev/null
	mv $title.pdb ../opt_pdbs

	# make SP-DFT .com input file
	cd $RM1_D/opt_pdbs/
	bash $FLOW_TOOLS/scripts/make-com.sh -i=$title.pdb -r='#p M06/6-31+G(d,p)' -c=$CHARGE_PDB -t=$title\_sp -l=$SP_DFT
	exit 0	
else
	# move files to failed directory
	mv $title* $RM1_D/failed/
	rm $SCRATCH/gamess_scratch/$title*
	rm $SCRATCH/gamess_scratch/scr/$title*
	exit 1
fi

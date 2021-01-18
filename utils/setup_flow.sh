#!/bin/bash

# script for automatically creating directory setup for database batch submissions
# takes N arguments which are the names of each flow.

for batch_title in "$@"; do

	# don't make directory if already exists
	if [ -d "$batch_title" ]; then echo "Omitting directory \"$batch_title\"; already exists"; continue; fi
	mkdir $batch_title && cd $batch_title

	# setup directory structure
	#mkdir unopt_pdbs pm7 rm1-d sp-dft sp-tddft s0_vac s0_solv sn_solv t1_solv cat-rad_solv cat-rad_vac all-logs mol-data flow-tools
	#for d in pm7 rm1-d sp-dft sp-tddft; do mkdir $d/completed $d/failed; done
	#for d in pm7 rm1-d s0_vac; do mkdir $d/opt_pdbs; done
	#for d in s0_vac s0_solv sn_solv t1_solv cat-rad_solv cat-rad_vac; do mkdir $d/completed $d/failed_opt $d/failed_freq $d/resubmits $d/freq_calcs; done
        # Z. Hu, PDF stage1, setup
        # Z. Hu, 01/12/2021 to 01/14/2021, include mo_overlap and eom_ccsd 
	mkdir unopt_pdbs pm7 rm1-d sp-dft sp-tddft all-logs mol-data flow-tools s0_vac soc mo_overlap eom_ccsd
	for d in pm7 rm1-d sp-dft eom_ccsd; do mkdir $d/completed $d/failed; done
	for d in pm7 rm1-d s0_vac; do mkdir $d/opt_pdbs; done
        for d in s0_vac; do mkdir $d/completed $d/failed_opt $d/resubmits; done
        for d in sp-tddft; do mkdir $d/b3lyp $d/wb97xd; done;
        for d in sp-tddft; do mkdir $d/b3lyp/completed $d/b3lyp/failed $d/wb97xd/completed $d/wb97xd/failed; done
        for d in soc; do mkdir $d/b3lyp $d/wb97xd; done;
        # mo_overlap
        mkdir sp-dft/solv
        for d in sp-dft; do mkdir $d/solv/completed $d/solv/failed; done

	# setup config
	rsync -r --exclude=setup-flow.sh --exclude=functions.sh $FLOW/* flow-tools/.

	cd ..

done

#!/bin/bash

# Script for automatically resubmitting optimization array which has been abruptly stopped
source_config

for i in "$@"; do
    case $i in
        -n|--nosubmit) NOSUBMIT=1 ;;
    esac
done

curr_dir=$PWD
if [[ "$curr_dir" =~ ^($S0_SOLV|$S1_SOLV|$T1_SOLV|$CAT_RAD_VAC|$CAT_RAD_SOLV)$ ]]; then
	structure_source=$S0_VAC/opt_pdbs
else
	echo "Error: must be in a DFT calculation directory."
	exit 1
fi

# completed molecules for current DFT directory
completed_opts=$(ls completed resubmits | egrep '.+(vac.log)|(solv.log)')
completed_inchis=$(for opt in $completed_opts; do echo $opt | cut -d'_' -f 1; done)

# completed s0_vac molecules
s0_vac_pdbs=$(ls $S0_VAC/opt_pdbs/*.pdb)
s0_vac_inchis=$(for pdb in $s0_vac_pdbs; do basename $pdb | cut -d'_' -f 1; done)

# incomplete molecules
incomplete_inchis=$(for i in $s0_vac_inchis; do if [[ ! "$completed_inchis[@]}" =~ "${i}" ]]; then echo $i; fi; done)
num_incomplete=$(for i in $incomplete_inchis; do echo $i; done | wc -l)

# exit if no jobs need to be resubmitted
if [[ "$num_incomplete" == 0 ]]; then
	echo "No jobs to resubmit."
	exit 0
fi

# pdbs to use as starting points for new optimizations
pdbs=$(for i in $incomplete_inchis; do echo "${i}_S0_vac.pdb"; done)

# Creates an input file given a PDB file as a starting point. The route, charge, and multiplicity are determined based on the current directory
function create_input_file {
    source_config
	local pdb_file=$structure_source/$1
	local inchi="${pdb/_S0_vac.pdb/}"
    local curr_dir=$PWD
    if [[ "$curr_dir" == "$S0_SOLV" ]]; then
		route='#p M06/6-31+G(d,p) SCRF=(Solvent=Acetonitrile) opt'; loc=$S0_SOLV; title=$inchi\_S0_solv; s=1; c=0
	elif [[ "$curr_dir" == "$S1_SOLV" ]]; then
		route='#p M06/6-31+G(d,p) SCRF=(Solvent=Acetonitrile) opt td=root=1'; loc=$S1_SOLV; title=$inchi\_S1_solv; s=1; c=0
	elif [[ "$curr_dir" == "$T1_SOLV" ]]; then
		route='#p M06/6-31+G(d,p) SCRF=(Solvent=Acetonitrile) opt td=(triplets, root=1)'; loc=$T1_SOLV; title=$inchi\_T1_solv; s=3; c=0
    elif [[ "$curr_dir" == "$CAT_RAD_VAC" ]]; then
		route='#p M06/6-31+G(d,p) opt'; loc=$CAT_RAD_VAC; title=$inchi\_cat_rad_vac; s=2; c=1
    elif [[ "$curr_dir" == "$CAT_RAD_SOLV" ]]; then
		route='#p M06/6-31+G(d,p) SCRF=(Solvent=Acetonitrile) opt'; loc=$CAT_RAD_SOLV; title=$inchi\_cat_rad_solv; s=2; c=1
    fi
	bash $FLOW/scripts/make-com.sh -i=$pdb_file -r="$route" -t=$title -c=$c -s=$s -l=$loc
}

echo "Creating input files..."
for pdb in $pdbs; do
	create_input_file $pdb
done

if [ -z "$NOSUBMIT" ]; then
	resubmit_array
else
	exit 0
fi

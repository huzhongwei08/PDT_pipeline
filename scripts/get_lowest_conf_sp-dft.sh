#!/bin/bash

# This script extracts the lowest energy conformer for conformers obtained from G16 optimization.
# Conformers are expected to have the name "MOLECULE_N.log" where N is the conformer number. The proper input
# for this script is "MOLECULE".


# molecule of interest
mol=$1
num_confs=$2
declare -a confs=()
declare -a energies=()

# gather energies of all conformers of the input molecule
for conf in $mol*.log; do
	confs+=($conf)
	energy=$(grep 'SCF Done' $conf | tail -1 | awk '{print $5}')
	energies+=($energy)
done


if [[ $num_confs -eq "${#energies[@]}" ]]; then
	# get the index of the lowest energy
	min_index=$(echo "${energies[*]}" | tr ' ' '\n' | awk 'NR==1{min=$0}NR>1 && $1<min{min=$1;pos=NR}END{print pos}')

	# get the lowest energy conformer
	min_conf=${confs[$(($min_index - 1))]}

	echo "${min_conf/_sp.log/}"
else
	echo "-1"
fi

#!/bin/bash

# script for starting workflow
# execute anywhere in workflow directory tree

# source config and function files
source_config

echo -e "\nCommencing workflow [Version $FLOW_VERSION]"
# convert pdbs to G16 input files for PM7 optimization
cd $UNOPT_PDBS
total_pdbs=$(ls -f *.pdb | wc -l)
current=1
echo -e "\nCreating PM7 input files..."
for file in *.pdb; do
	progress_bar 100 0 $current $total_pdbs
	bash $FLOW_TOOLS/scripts/make-com.sh -i=$file -r='#p pm7 opt' -c=$CHARGE_PDB -l=$PM7 -f
	current=$((current + 1))
done
echo ""

# submit PM7 optimization array
cd $PM7
PM7_ID=$(submit_array "$TITLE\_PM7" "g16_inp.txt" "com" "$FLOW_TOOLS/templates/array_g16_pm7.sbatch" $PM7_TIME)
echo "PM7 array submitted with job ID $PM7_ID"

# submit RM1-D submitter which submits after PM7 array completes
cd $RM1_D
RM1_ID=$(sed "s/PM7_ID/$PM7_ID/g" "$FLOW_TOOLS/templates/rm1-d_submitter.sbatch" | sbatch)
echo -e "RM1-D_submitter queued with job ID $RM1_ID\n"


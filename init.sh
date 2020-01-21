#!/bin/bash

# This script will modify the .bashrc file to add the $FLOW environment variable and 
# source functions necessary for the workflow. The location of the .bashrc file is 
# assumed to be ~/.bashrc; if this is not the case, specify the correct location below.

bashrc_source=~/.bashrc

scratch_dir=/scratch/$USER

utils_header='# VERDE Materials DB workflow utils'

# ensure .bashrc exists and check if already modified
if [ ! -f "$bashrc_source" ]; then
	echo "Error: .bashrc not found at $bashrc_source"
	exit 1
elif [ $(grep -c "$utils_header" "$bashrc_source") -ge 1 ]; then
	echo ".bashrc already modified."
else
	FLOW=$(pwd)
	echo -e "$utils_header\nexport SCRATCH=$scratch_dir\nexport FLOW=$FLOW\nset -a; source $FLOW/functions.sh; set +a\n" >> "$bashrc_source"
	echo "Successfully initialized VERDE workflow variables."
fi

# modify rungms
rungms_path=$(whereis rungms | awk '{print $NF}')
gamess_source=$(dirname $rungms_path)

if [ ! -d "$scratch_dir/gamess_scratch/scr" ]; then
	mkdir -p $scratch_dir/gamess_scratch/scr
fi

if [ $(grep -c '#set SCR=/scratch/$USER/gamess_scratch/' "$FLOW/utils/rungms") -eq 1 ]; then
	sed -i 's|#set SCR=/scratch/$USER/gamess_scratch/|set SCR=$SCRATCH/gamess_scratch|' $FLOW/utils/rungms
	sed -i 's|#set USERSCR=/scratch/$USER/gamess_scratch/scr/|set USERSCR=$SCRATCH/gamess_scratch/scr|' $FLOW/utils/rungms
	sed -i "s|#set GMSPATH=/shared/centos7/gamess/2018R1|set GMSPATH=$gamess_source|" $FLOW/utils/rungms
fi

echo "Initialization complete."


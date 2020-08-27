#!/bin/bash

# searches upwards for the given directory
function upsearch {
    local cur_dir=$PWD
    test / == "$PWD" && return || test -e "$1" && echo "$PWD" && return || cd .. && upsearch "$1"
    cd $cur_dir
}

# sources the config file for the flow directory
function source_config {
    local cur_dir=$PWD
    local main_dir=$(upsearch flow-tools)
    cd $main_dir
	. "flow-tools/config.sh"
    cd $cur_dir
}

# copies the optimized S0_vac PDB files for the incomplete jobs in the current job directory  
function copy_opt_pdbs {
	source_config
	local opt_pdbs=$(for file in $S0_VAC/opt_pdbs/*.pdb; do base=$(basename $file); echo "${base/_S0_vac.pdb/}"; done)
	local to_copy=$(for file in $opt_pdbs; do c=$(ls completed/$file* 2>/dev/null | wc -l); if [[ $c -eq 0 ]]; then echo $file; fi; done)
	for file in $to_copy; do cp $S0_VAC/opt_pdbs/$file*.pdb $file.pdb; done
}

function move_freq_to_temp {
	mkdir temp
	for file in *freq.log; do mv "${file/_freq.log/}"* temp; done
}

function resub_all_freqs {
	source_config
	move_freq_to_temp
	for file in *.log; do
		setup_freq $file
	done
	mv temp/* . && rmdir temp
}

function transfer_all_logs {
	source_config
	for d in "$S0_VAC" "$S0_SOLV" "$SN_SOLV" "$T1_SOLV" "$CAT_RAD_VAC" "$CAT_RAD_SOLV" "$SP_TDDDFT"; do
		cp $d/completed/*.log $ALL_LOGS
	done
}

function gen_slurm_report {
	printf "%-20s %-15s\n" "CLUSTER" "$SLURM_CLUSTER_NAME"
	printf "%-20s %-15s\n" "SLURM_JOB_ID" "$SLURM_JOB_ID"
	printf "%-20s %-15s\n" "SLURM_ARRAY_JOB_ID" "$SLURM_ARRAY_JOB_ID"
	printf "%-20s %-15s\n" "SLURM_ARRAY_TASK_ID" "$SLURM_ARRAY_TASK_ID"
	printf "%-20s %-15s\n" "PARTITION" "$SLURM_JOB_PARTITION"
	printf "%-20s %-15s\n" "JOBNAME" "$SLURM_JOB_NAME"
	printf "%-20s %-15s\n" "SLURM_JOB_NODELIST" "$SLURM_JOB_NODELIST"
	printf "%-20s %-15s\n" "Groups" "$(groups)"
	printf "%-20s %-15s\n" "Submission time" "$(date +"%H:%M:%S | %b %d %y")"
}

# function which sets up an sbatch email for the given job id
# use: email-sbatch <title> <jobid>
# effect: submits a job which waits until the job with the given id completes, then sends an email
function email_sbatch {
	local title=$1 # title of the job
	local jobid=$2 # job-id which you would like to be notified about
	sed "s/JOBID/$jobid/g" $FLOW_TOOLS/templates/email.sbatch | sed "s/EMAIL/$DEFAULT_EMAIL/g" | sed "s/JOBNAME/$title/g" | sed "s/PARTITION/$DEFAULT_PARTITION/g" | sbatch 1>/dev/null
}

# function which submits all 

# function which submits an array of input files
# use: submit-array <array_title> <inp_file_list> <inp_file_type> <partition> <sbatch_file>
# effect: submits an array of jobs
function submit_array {
	local array_title=$1
	local inp_file_list=$2
	local inp_file_type=$3
	local sbatch_file=$4
	local calc_time=$5

	source_config

	# create list of input files
	ls *."$inp_file_type" > "$inp_file_list"

	# number of files in the array
	local numfiles=$(wc -l <$inp_file_list)

	# substitute ARRAY_TITLE with name of super-directory and TOTAL with the number of files
	# in the array then submit sbatch
	local jobid=$(sed "s/JOBNAME/$array_title/g" $sbatch_file | sed "s/SIMULTANEOUS_JOBS/$DEFAULT_SIMULTANEOUS_JOBS/" | sed "s/TOTAL/$numfiles/g" | sed "s/TIME/$calc_time/" | sbatch)

	# submit separate sbatch for array email
	email_sbatch $array_title $jobid

	echo $jobid
}

# function which renames slurm array output files
# use: rename-slurm-outputs <id> <title>
# effect: renames output and error files
function rename_slurm_outputs {
	local id=$1
	local title=$2
	mv *"_$id.o" $title.o
	mv *"_$id.e" $title.e
}

# function which fetches the line number from the given file matching the given slurm array task id
# use: fetch-input <id> <file>
# effect: echoes the name of the input file
function fetch_input {
	local id=$1
	local file=$2
	local input_file=$(sed -n "$id"p $file | cut -f 1 -d '.')
	echo $input_file
}

# job completion handlers

# basic job handler (only checks for completed or failed and moves files accordingly)
# use: basic-job-handler <title> <termination>
# effect moves all files beginning with the given title into the completed or failed directory
function basic_job_handler {
	local title=$1
	local termination=$2
	if [ $termination -ge 1 ]; then # if the run terminated successfully
		mv $title* completed/
		exit 0
	else # if the run fails
		mv $title* failed/
		exit 1
	fi
}

# creates an xyz file by extracting coordinates from the given log file
# use: pull-xyz-geom <log>
# effect: creates an xyz file with the same name as the log file
function pull_xyz_geom {
	local log=$1
	local title="${log/.log/}"
	local xyz=$title.xyz
	local charge=$(grep 'Charge =' $log | awk '{print $3}')
	local mult=$(grep 'Charge =' $log | awk '{print $6}')
	local geom=$(grep -ozP '(?s)\\\\'"$charge"",""$mult"'\\\K.*?(?=\\\\Version)' $log |
		sed 's/ //g' | tr -d '\n')
	local IFS='\' read -r -a coords <<<"$geom"
	echo ${#coords[@]} >$xyz
	echo $title >>$xyz
	printf '%s\n' "${coords[@]}" | sed 's/,/\t\t/g' >>$xyz
}

# draws a progress bar for a for loops given the barsize and length of the loop
# use: progress-bar <barsize> <base> <current> <total>
# effect: prints a progress bar as the for loop runs
function progress_bar {
	local barsize=$1
	local base=$2
	local current=$3
	local total=$4
	local j=0
	local progress=$((($barsize * ($current - $base)) / ($total - $base)))
	echo -n "["
	for ((j = 0; j < $progress; j++)); do echo -n '='; done
	echo -n '=>'
	for ((j = $progress; j < $barsize; j++)); do echo -n ' '; done
	echo -n "] $(($current)) / $total " $'\r'
}

# finds the given directory by inverse recursion
# use: upsearch <file or directory name>
# effect: echoes the directory of the found file
function upsearch {
	local cur_dir=$PWD
	test / == "$PWD" && return || test -e "$1" && echo "$PWD" && return || cd .. && upsearch "$1"
	cd $cur_dir
}

# sets up the given .com file for restart using the given sbatch file
# use: restart_opt <title> <sbatch file>
# effect: modifies the input file using restart-g16.py then creates an sbatch file and submits it
function restart_opt {
	local title=$1
	local sbatch_file=$2
	local input_file=$title.com
    python $FLOW/scripts/restart-g16.py $input_file
    setup_sbatch $input_file $sbatch_file
    sbatch $title.sbatch
}

# updates the workflow to use the latest code
# use: update_existing_flow (use anywhere in your workflow directories)
# effect: updates files in the "flow_tools" directory
function update_existing_flow {
	local cur_dir=$PWD
	source_config
	cd $FLOW_TOOLS
	rsync -r --exclude=setup-flow.sh --exclude=test --exclude=functions.sh --exclude=LICENSE --exclude=README.md $FLOW/* .
	cd $cur_dir
}

# extracts data from completed log files
# use: extract_data (use anywhere in your workflow directories)
# effect: generates .json and .xyz files in the mol-data folder of the workflow
function extract_data {
	python $FLOW/utils/data_extractor.py
}

# sets up the given .com file for restart (intended for PM7 optimization)
# use: pm7-restart <com file>
# effect: modifies the input file by changing the route and deleting the coordinates
function pm7_restart {
	local com_file=$1
	local route=$(grep '#' $com_file)
	sed -i '/[0-9] [0-9]/,$d' $com_file & wait
	sed -i "s/$route/#p pm7 opt=calcfc geom=allcheck/" $com_file & wait
}

# sets up sbatch script for given .com file and sbatch template
# use: setup-sbatch <com file> <sbatch template>
# effect: copies a new sbatch file to the current directory and substitutes the placeholders
function setup_sbatch {
	local input=$1
	local sbatch_template=$2
	local title="${input/.com/}"
	local batch_file="$title.sbatch"

	cp "$sbatch_template" "$batch_file" & wait
	sed -i "s/JOBNAME/$title/" "$batch_file" & wait
	sed -i "s/PARTITION/$DEFAULT_PARTITION/" "$batch_file" & wait
	sed -i "s/TIME/$DFT_TIME/" "$batch_file" & wait
	sed -i "s/EMAIL/$DEFAULT_EMAIL/" "$batch_file" & wait
}

# determines if the job with the given title is finished
function job_finished {
	local output_file_name=$1
	echo $(ls completed/$output_file_name 2>/dev/null | wc -l)
}

# determines if the job with the given title has failed
function job_failed {
	local output_file_name=$1
	local fail_dir=$2
	echo $(ls $fail_dir/$output_file_name 2>/dev/null | wc -l)
}

# sets up frequency calculation from geometry from given log file
# use: setup-freq <log file>
# effect: creates an input and sbatch file for a frequency job and submits it
function setup_freq {
	source_config
	local log_file=$1
	local com_file="${log_file/.log/.com}"
	local route=$(grep '#p' $com_file)
	local opt_keyword=$(echo $route | awk '/opt/' RS=" ")
	local charge=$(grep 'Charge =' $log_file | awk '{print $3}')
    local mult=$(grep 'Charge =' $log_file | awk '{print $6}')
	local freq="${log_file/.log/_freq}"
	local new_route=$(echo $route | sed "s|$opt_keyword|freq=noraman|" | sed "s| geom=allcheck guess=read||")
	
	# setup freq job
	bash $FLOW_TOOLS/scripts/make-com.sh -i="$log_file" -r="$new_route" -c="$charge" -s="$mult" -t="$freq" -l="../freq_calcs/"
	cd "../freq_calcs/"

	# setup sbatch
	cp $FLOW_TOOLS/templates/freq_sbatch.txt $freq.sbatch
	sed -i "s/JOBNAME/$freq/g" $freq.sbatch
	sed -i "s/EMAIL/$DEFAULT_EMAIL/" $freq.sbatch
	sed -i "s/TIME/$DFT_TIME/" $freq.sbatch
	sed -i "s/PARTITION/$DEFAULT_PARTITION/" $freq.sbatch
	sbatch $freq.sbatch

	cd "../completed/"
}

# moves the given log file to the all-logs folder of the workflow
# use: to_all_logs <log file>
# effect: copies the log file to "all-logs"
function to_all_logs {
	source_config
	local log_file=$1
	cp $log_file $ALL_LOGS
}


function cp_all_logs {
	source_config
	for d in $CAT_RAD_VAC $CAT_RAD_SOLV $PM7 $RM1_D $S0_VAC $S0_SOLV $S1_SOLV $SP_TDDFT $SP_DFT $T1_SOLV $T1_SP_DDFT; do
		cp $d/completed/*.log $ALL_LOGS;
	done
}

function submit_all_dft_opts {
	local inchi_key=$1
	for d in $S0_SOLV $S1_SOLV $T1_SOLV $CAT_RAD_VAC $CAT_RAD_SOLV; do
		cd $d && sbatch $inchi_key*sbatch;
	done
}

# resubmits the jobs in the current directory
# use: resubmit_array (no arguments, simply call from the workflow directory containing jobs you want to resubmit)
# effect: submits an array of jobs
function resubmit_array {
	source_config
	local curr_dir=$PWD
    get_missing_input_files
    if [[ "$curr_dir" == "$S0_VAC" ]]; then
        jobid=$(submit_array "$TITLE\_S0_VAC" "g16_inp.txt" "com" "$FLOW_TOOLS/templates/array_g16_s0_dft-opt_vac.sbatch" "$DFT_TIME")
		sed "s/S0_DFT_OPT_VAC_ID/$jobid/g" $FLOW_TOOLS/templates/dft-opt_submitter.sbatch | sbatch
	elif [[ "$curr_dir" == "$S0_SOLV" ]]; then
		jobid=$(submit_array "$TITLE\_S0_SOLV" "g16_inp.txt" "com" "$FLOW_TOOLS/templates/array_g16_dft-opt.sbatch" "$DFT_TIME")
	elif [[ "$curr_dir" == "$S1_SOLV" ]]; then
		jobid=$(submit_array "$TITLE\_S1_SOLV" "g16_inp.txt" "com" "$FLOW_TOOLS/templates/array_g16_dft-opt.sbatch" "$DFT_TIME")
	elif [[ "$curr_dir" == "$SN_SOLV" ]]; then
		jobid=$(submit_array "$TITLE\_SN_SOLV" "g16_inp.txt" "com" "$FLOW_TOOLS/templates/array_g16_dft-opt.sbatch" "$DFT_TIME")
	elif [[ "$curr_dir" == "$T1_SOLV" ]]; then
        jobid=$(submit_array "$TITLE\_T1_SOLV" "g16_inp.txt" "com" "$FLOW_TOOLS/templates/array_g16_dft-opt.sbatch" "$DFT_TIME")
	elif [[ "$curr_dir" == "$CAT_RAD_VAC" ]]; then
        jobid=$(submit_array "$TITLE\_CAT-RAD_VAC" "g16_inp.txt" "com" "$FLOW_TOOLS/templates/array_g16_dft-opt.sbatch" "$DFT_TIME")
	elif [[ "$curr_dir" == "$CAT_RAD_SOLV" ]]; then
        jobid=$(submit_array "$TITLE\_CAT-RAD_SOLV" "g16_inp.txt" "com" "$FLOW_TOOLS/templates/array_g16_dft-opt.sbatch" "$DFT_TIME")
	elif [[ "$curr_dir" == "$SP_TDDFT" ]]; then
		jobid=$(submit_array "$TITLE\_SP-TDDFT" "g16_inp.txt" "com" "$FLOW_TOOLS/templates/array_g16_sp_td-dft.sbatch" "$DFT_TIME")
	elif [[ "$curr_dir" == "$PM7" ]]; then
		jobid=$(submit_array "$TITLE\_PM7" "g16_inp.txt" "com" "$FLOW_TOOLS/templates/array_g16_pm7.sbatch" "$PM7_TIME")
	elif [[ "$curr_dir" == "$RM1_D" ]]; then
		jobid=$(submit_array "$TITLE\_RM1-D" "gamess_inp.txt" "inp" "$FLOW_TOOLS/templates/array_gamess_rm1-d.sbatch" "$DFT_TIME")
		sed "s/RM1_ID/$jobid/g" $FLOW_TOOLS/templates/sp-dft_submitter.sbatch | sbatch
	elif [[ "$curr_dir" == "$SP_DFT" ]]; then
		jobid=$(submit_array "$TITLE\_SP-DFT" "g16_inp.txt" "com" "$FLOW_TOOLS/templates/array_g16_sp-dft.sbatch" "$DFT_TIME")
		LEE_ID=$(sed "s/SP_DFT_ID/$jobid/" $FLOW_TOOLS/templates/least-energy-extractor.sbatch | sed "s/EMAIL/$DEFAULT_EMAIL/" | sbatch)
		cd $MAIN_DIR
		sed "s/LEE_ID/$LEE_ID/g" $FLOW_TOOLS/templates/dft-vee_submitter.sbatch | sbatch
	fi
	echo "Submitted array with job ID: $jobid"
}

# resubmits all DFT arrays
# use: resubmit_all_dft_arrays
# effect: submits several arrays of jobs
function resubmit_all_dft_arrays {
	source_config
	local curr_dir=$PWD
	for d in $S0_SOLV $SN_SOLV $T1_SOLV $CAT_RAD_VAC $CAT_RAD_SOLV; do
		cd $d
		get_missing_input_files
		num_files=$(ls *.com | wc -l)
		if [[ $num_files -gt 0 ]]; then
			resubmit_array
		fi
	done
	cd $curr_dir
}

# creates all missing input files for the current directory
#
# effect: Creates .com files for all incomplete jobs in current flow directory
function get_missing_input_files {
	source_config
	local curr_dir=$PWD
	copy_opt_pdbs
    if [[ "$curr_dir" == "$S0_SOLV" ]]; then
		for file in *.pdb; do inchi="${file/.pdb/}"; bash $FLOW/scripts/make-com.sh -i=$file -r='#p M06/6-31+G(d,p) SCRF=(Solvent=Acetonitrile) opt' -t=$inchi\_S0_solv -l=$S0_SOLV -f; rm $file; done
    elif [[ "$curr_dir" == "$SN_SOLV" ]]; then
		for file in *.pdb; do 
			inchi="${file/.pdb/}"; root=$(get_root $inchi)
			re='^[0-9]+$'
			if [[ $root =~ $re ]] ; then
				title="${inchi}_S${root}_solv"
				bash $FLOW/scripts/make-com.sh -i=$file -r="#p M06/6-31+G(d,p) SCRF=(Solvent=Acetonitrile) opt td=root=$root" -t=$title -l=$SN_SOLV -f
			fi
		rm $file
		done
	elif [[ "$curr_dir" == "$T1_SOLV" ]]; then
		for file in *.pdb; do inchi="${file/.pdb/}"; bash $FLOW/scripts/make-com.sh -i=$file -r='#p M06/6-31+G(d,p) SCRF=(Solvent=Acetonitrile) opt td=root=1' -s=3 -t=$inchi\_T1_solv -l=$T1_SOLV -f; rm $file; done
    elif [[ "$curr_dir" == "$CAT_RAD_VAC" ]]; then
		for file in *.pdb; do inchi="${file/.pdb/}"; bash $FLOW/scripts/make-com.sh -i=$file -r='#p M06/6-31+G(d,p) opt' -t=$inchi\_cat-rad_vac -l=$CAT_RAD_VAC -f; rm $file; done
    elif [[ "$curr_dir" == "$CAT_RAD_SOLV" ]]; then
		for file in *.pdb; do inchi="${file/.pdb/}"; bash $FLOW/scripts/make-com.sh -i=$file -r='#p M06/6-31+G(d,p) SCRF=(Solvent=Acetonitrile) opt' -t=$inchi\_cat-rad_solv -c=1 -s=2 -l=$CAT_RAD_SOLV -f; rm $file; done
	elif [[ "$curr_dir" == "$RM1_D" ]]; then
		echo "UNSUPPORTED"
	fi
}


# determines the root to which to optimize the given file
function get_root {
	source_config
	local inchi=$1
	oscillator_strengths=$(grep 'Excited S' "$SP_TDDFT/completed/${inchi}_sp-tddft.log" 2>/dev/null | head -5 | awk '{print $9}')
	i=1
	for o in $oscillator_strengths; do
		os="${o/2:7}"
		if [[ $(echo $os ">=" 0.1 | bc -l) -eq 1 ]]; then
			local n=$i;
			break;
		else
			let "i++"
		fi
	done
	if [ ! -z $n ]; then
		echo $n
        unset n
	fi
}


# updates the workflow code by pulling the most recent files from GitHub
# use: update_flow
# effect: Updates $FLOW directory to match GitHub repository
function update_flow {
    local curr_dir=$PWD
    cd $FLOW
    git pull
	source ~/.bashrc
    cd $curr_dir
}

# begins a workflow
# use: begin_calcs
# effect: submits workflow to queue
function begin_calcs {
	source_config
	local curr_dir=$PWD
	cd $MAIN_DIR
	bash $FLOW_TOOLS/begin_calcs.sh
	cd $curr_dir
}


# restarts a workflow that was stopped
function restart_flow {
	source_config
	local curr_dirr=$PWD

}

# checks the progress of a workflow
# use: check_prog
# effect: displays a table showing calculation progress for a workflow
function check_prog {
	bash $FLOW/utils/check_prog.py
}

# creates workflow directory tree
# use: setup_flow <workflow_name>
# effect: creates a workflow directory with the given name
function setup_flow {
	bash $FLOW/utils/setup_flow.sh "$@"
}

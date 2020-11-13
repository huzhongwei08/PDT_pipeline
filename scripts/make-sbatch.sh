#!/bin/bash

# script for setting up sbatch

for i in "$@"; do
	case $i in
		-j=*|--jobname=*) JOBNAME="${i#*=}"; SBATCH=$JOBNAME.sbatch ;;
		-i=*|--input=*) INPUT="${i#*=}"; FILE=$(basename -- "$INPUT"); TYPE="${FILE##*.}" ;;
		-p=*|--partition=*) PARTITION="${i#*=}" ;;
		-N=*|--nodes=*) NODES="${i#*=}" ;;
        -n=*|--cores=*) CORES="${i#*=}" ;;
        -l=*|--location=*) LOCATION="${i#*=}" ;;
		-d=*|--dependency=*) DEPENDENCY="${i#*=}" ;;
		-c=*|--commands=*) COMMANDS="${i#*=}" ;;
		-a=*|--array=*) ARRAY="${i#*=}" ;;
        -f|--force) FORCE=1 ;;
		-e|--email) EMAIL=1 ;;
		-m=*|--mailtype=*) MAILTYPE="${i#*=}" ;;
		-u=*|--user=*) USER="${i#*=}" ;;
		-s|--submit) SUBMIT=1 ;;
    esac
done

# errors
if [ -z "$INPUT" ]; then echo 'error: input file not specified; use -i or --input option'; exit 1; fi

# default jobname
if [ -z "$JOBNAME" ]; then JOBNAME="${FILE/.$TYPE/}"; SBATCH=$JOBNAME.sbatch; fi

# check if sbatch file already exists
if [[ $FORCE -eq 1 ]]; then rm $JOBNAME.sbatch 2>/dev/null
else
	while [ -f "$JOBNAME.sbatch" ] && [[ ! $FORCE -eq 1 ]]; do
		read -p "$JOBNAME.sbatch already exists. Do you wish to overwrite this file? (y/n)" yn
		case $yn in
			[Yy]* ) rm $JOBNAME.sbatch; break;;
			[Nn]* ) exit 0;;
			* ) echo "Please answer yes or no.";;
		esac
	done
fi

# default commands
if [ -z "$COMMANDS" ]; then
	if [[ "$TYPE" == "com" ]]; then COMMANDS=$FLOW/templates/commands/default_g16.txt
	elif [[ "$TYPE" == "inp" ]]; then COMMANDS=$FLOW/templates/commands/default_gamess.txt
	else echo -e "error: default commands not available for input of type \".$TYPE\"; please specify commands"; exit 1; fi
fi

# other defaults
if [ -z "$PARTITION" ]; then PARTITION='general'; fi
if [ -z "$NODES" ]; then NODES=1; fi
if [ -z "$CORES" ]; then CORES=16; fi
if [ -z "$LOCATION" ]; then LOCATION='.'; fi
if [ -z "$MAILTYPE" ]; then MAILTYPE='END'; fi
if [ -z "$SUBMIT" ]; then SUBMIT=0; fi
if [ -z "$EMAIL" ]; then EMAIL=0; fi
if [ -z "$USER" ]; then USER=$LOGNAME@husky.neu.edu; fi

# create SBATCH header
echo "#!/bin/bash" >> $SBATCH
echo "#SBATCH --job-name=$JOBNAME" >> $SBATCH
echo "#SBATCH --output=$JOBNAME.o" >> $SBATCH
echo "#SBATCH --error=$JOBNAME.e" >> $SBATCH
echo "#SBATCH -N $NODES" >>$SBATCH
echo "#SBATCH -n $CORES" >> $SBATCH
echo "#SBATCH -p $PARTITION" >> $SBATCH
if [ -n "$DEPENDENCY" ]; then echo "#SBATCH --dependency=afterany:$DEPENDENCY" >> $SBATCH; fi 
if [[ $EMAIL -eq 1 ]]; then echo "#SBATCH --mail-user=$USER@husky.neu.edu" >> $SBATCH; fi
if [[ $EMAIL -eq 1 ]]; then echo "#SBATCH --mail-type=$MAILTYPE" >> $SBATCH >> $SBATCH; fi
echo "#SBATCH --parsable" >> $SBATCH
echo "" >> $SBATCH

# add commands
if [ -f "$COMMANDS" ]; then cat $COMMANDS | sed "s/JOBNAME/$JOBNAME/g" >> $SBATCH; fi

# move file
if [[ ! "$LOCATION" == '.' ]]; then mv $SBATCH $LOCATION; fi

# submit sbatch
if [[ $SUBMIT == 1 ]]; then cd $LOCATION && sbatch $SBATCH; fi


#!/bin/bash

# script for creating G16 input files

# input handler
for i in "$@"; do
	case $i in
		-t=*|--title=*) INPUT_TITLE="${i#*=}"; COM=$INPUT_TITLE.com ;;
		-r=*|--route=*) ROUTE="${i#*=}" ;;
		-n=*|--nproc=*) NPROC="${i#*=}" ;;
		-m=*|--mem=*) MEM="${i#*=}" ;;
		-c=*|--charge=*) CHARGE="${i#*=}" ;;
		-s=*|--mult=*) MULT="${i#*=}" ;;
		-i=*|--input=*) INPUT="${i#*=}"; FILE=$(basename "$INPUT"); TYPE="${FILE##*.}" ;;
		-y=*|--type=*) INPUT_TYPE="${i#*=}" ;;
		-w=*|--rwf=*) RWF="${i#*=}" ;;
		-k=*|--chk=*) CHK="${i#*=}" ;;
		-ns=*|--nosave=*) NOSAVE="${i#*=}" ;;
		-l=*|--location=*) LOCATION="${i#*=}" ;;
		-f|--force) FORCE=1 ;;
		-b|--sbatch) SBATCH=1 ;;
		-b+|--sbatch+) SBATCH=2 ;;
	esac
done

# errors
if [ -z "$INPUT" ]; then echo 'error: input geometry not provided; use -i or --input option'; exit 1; fi
if [ -z "$ROUTE" ]; then 
	echo 'error: route not requested; use -r or --route option'
	exit 1
else
	ROUTE=$(echo $ROUTE | tr -d '"' | tr -d "\'")
fi

# default title
if [ -z "$INPUT_TITLE" ]; then INPUT_TITLE="${FILE/.$TYPE/}"; COM=$INPUT_TITLE.com; fi

# check if input file already exists
if [[ $FORCE -eq 1 ]]; then
	rm "$INPUT_TITLE.com" 2>/dev/null
else
	while [ -f "$INPUT_TITLE.com" ] && [[ ! $FORCE -eq 1 ]]; do
		read -p "$INPUT_TITLE.com already exists. Do you wish to overwrite this file? (y/n): " yn
		case $yn in
			[Yy]* ) rm $INPUT_TITLE.com; break;;
			[Nn]* ) exit 0;;
			* ) echo "Please answer yes or no.";;
		esac
	done
fi

# defaults
if [ -z "$NPROC" ]; then NPROC=14; fi
if [ -z "$MEM" ]; then MEM=8; fi
if [ -z "$CHARGE" ]; then CHARGE=0; fi
if [ -z "$MULT" ]; then MULT=1; fi
if [ -z "$RWF" ]; then RWF=$INPUT_TITLE.rwf; fi
if [ -z "$CHK" ]; then CHK=$INPUT_TITLE.chk; fi
if [ -z "$NOSAVE" ]; then NOSAVE="ALL"; else NOSAVE="${NOSAVE^^}"; fi
if [ ! -z "$INPUT_TYPE" ]; then TYPE=$INPUT_TYPE; fi
if [ -z $LOCATION ]; then LOCATION='.'; fi

# build route card
if [[ "$NOSAVE" == "ALL" ]]; then echo -e "%chk=$CHK\n%rwf=$RWF\n%NoSave" >> "$COM"
elif [[ "$NOSAVE" == "RWF" ]]; then echo -e "%rwf=$RWF\n%NoSave\n%chk=$CHK" >> "$COM"
elif [[ "$NOSAVE" == "CHK" ]]; then echo -e "%chk=$CHK\n%NoSave\n%rwf=$RWF" >> "$COM"
elif [[ "$NOSAVE" == "FALSE" ]]; then echo -e "%chk=$CHK\n%rwf=$RWF" >> "$COM"; fi
echo "%mem=$MEM""GB" >> "$COM"
echo "%nproc=$NPROC" >> "$COM"
echo -e "$ROUTE\n" >> "$COM"
echo -e "$INPUT_TITLE\n" >> "$COM"
echo "$CHARGE $MULT" >> "$COM"

# create formatted coordinates
obabel -i $TYPE $INPUT -o com 2>/dev/null | sed -e '1,5d' >> "$COM"

# move file to location 
if [[ ! "$LOCATION" -ef . ]]; then mv "$COM" "$LOCATION"; fi

# make sbatch
if [[ $SBATCH -eq 1 ]]; then cd $LOCATION && bash $FLOW/scripts/make-sbatch.sh -i=$COM -n=$NRPOC
elif [[ $SBATCH -eq 2 ]]; then cd $LOCATION && bash $FLOW/scripts/make-sbatch.sh -i=$COM -n=$NPROC -s; fi

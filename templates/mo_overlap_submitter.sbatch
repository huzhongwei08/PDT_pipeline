#!/bin/bash
#SBATCH -J MO_OVERLAP_submitter
#SBATCH -o MO_OVERLAP_submitter.o
#SBATCH -e MO_OVERLAP_submitter.e
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --partition=short
#SBATCH --constraint=ib
#SBATCH --time=24:00:00
#SBATCH --mem=16GB
#SBATCH --parsable
#SBATCH --dependency=afterany:SP_DFT_SOLV_ID

# source config and function files
source_config

# this sbatch script does not run until the completion of the SP_DFT_SOLV array
# Make a folder for each molecule/inchikey and perform MO Overlap
cd $MO_OVERLAP
for file in $SP_DFT/solv/completed/*.chk; do
    name=$(echo $(basename $file) | sed "s/.chk//")
    inchi_key="${name:0:27}"

    mkdir -p $inchi_key
    cd $inchi_key

    #mv $SP_DFT/solv/completed/${name}.chk .
    cp $SP_DFT/solv/completed/${name}.chk .

    # Convert *chk file to *fchk
    formchk ${name}.chk ${name}.fchk

    # Obtain the cube files for both HOMO and LUMO
    cubegen 1 MO=HOMO ${name}.fchk ${inchi_key}_HOMO.cub 0 h
    cubegen 1 MO=LUMO ${name}.fchk ${inchi_key}_LUMO.cub 0 h
    
    # Calculate the overlap between HOMO and LUMO
    python $FLOW_TOOLS/scripts/calc_mo_overlap.py ${inchi_key}_HOMO.cub ${inchi_key}_LUMO.cub > mo_overlap_out.dat

    cd $MO_OVERLAP
done

#!/bin/bash
#SBATCH -J SOC_submitter
#SBATCH -o SOC_submitter.o
#SBATCH -e SOC_submitter.e
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --partition=lopez
#SBATCH --constraint=ib
#SBATCH --time=24:00:00
#SBATCH --parsable
#SBATCH --dependency=afterany:SP_TDDFT_ID

# source config and function files
source_config

# this sbatch script does not run until the completion of the SP_TDDFT array
# Make a folder for each molecule/inchikey and perform PySOC
cd $SOC
for file in $SP_TDDFT/completed/*.rwf; do
    name=$(echo $(basename $file) | sed "s/.rwf//")
    inchi_key="${name:0:27}"

    mkdir -p $inchi_key
    cd $inchi_key

    cp $SP_TDDFT/completed/${name}.log .
    mv $SP_TDDFT/completed/${name}.rwf .

    cp $FLOW_TOOLS/pysoc/init_orig.py init.py

    # Path of molsoc 
    molsoc_path=$FLOW_TOOLS/pysoc/molsoc0.1.exe

    # Update the path of molsoc
    sed -i "s|./molsoc0.1.exe|$molsoc_path|" init.py
    
    # Gaussian log and rwf files
    log_file=$(echo *.log)
    rwf_file=$(echo *.rwf)
    
    # Update the log and rwf info. in "init.py"
    sed -i "s|gaussian.log|$log_file|" init.py
    sed -i "s|gaussian.rwf|$rwf_file|" init.py
    
    # Initialization for PySOC 
    python init.py
    
    # Run the soc.py
    $FLOW_TOOLS/pysoc/soc.py
    
    # Run the soc_td
    $FLOW_TOOLS/pysoc/soc_td

    cd $SOC
done

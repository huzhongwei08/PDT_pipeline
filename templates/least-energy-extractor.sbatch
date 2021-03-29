#!/bin/bash
#SBATCH -J least-energy-extractor
#SBATCH -o least-energy-extractor.o
#SBATCH -e least-energy-extractor.e
#SBATCH -N 1                                    
#SBATCH -n 16
#SBATCH --partition=short
#SBATCH --constraint=ib
#SBATCH --time=24:00:00
#SBATCH --mail-user=EMAIL
#SBATCH --mail-type=END
#SBATCH --parsable
#SBATCH --dependency=afterany:SP_DFT_SOLV_ID

# source config and function files
source_config

gen_slurm_report

cd $SP_DFT_SOLV/completed/

rm $SP_DFT_SOLV/lowest-energy-conformers.txt
touch $SP_DFT_SOLV/lowest-energy-conformers.txt


for conf in $UNOPT_PDBS/*_0.pdb; do
    name=$(echo $(basename $conf) | sed "s/_0.pdb//")
    # --------------------------------------------------------------
    # Z. Hu, include inchi_key for counting the number of conformers
    inchi_key="${name:0:27}"
    conf_num=$(find $UNOPT_PDBS -name $inchi_key*.pdb | wc -l)
    # --------------------------------------------------------------
    lowest=$(bash $FLOW_TOOLS/scripts/get_lowest_conf_sp-dft.sh $name $conf_num)

    # do not create input files if not all conformers are optimized
    if [[ $lowest -eq -1 ]]; then
        continue
    fi

    #output_file="$lowest\_sp.log"
    output_file="$lowest"
    to_all_logs $output_file
    #pdb=$lowest.pdb
    pdb=${lowest:0:29}.pdb
    #cd $RM1_D/opt_pdbs/
    cd $S0_DFT_OPT_SOLV/opt_pdbs/
    
    # -------------------------------------------------------------------
    # Z. Hu, obtain the charge for the PDB file
    filename=$(basename $pdb)
    CHARGE_PDB=$(python $FLOW_TOOLS/scripts/charge_from_pdb_each.py $UNOPT_PDBS/${filename:0:27}_0.pdb)
    # -------------------------------------------------------------------
    # -----------------------------------------------------------------------------------------------------------------
    # Z. Hu, make DFT S0 optimization .com file and move to dft_opt_s0 directory
    # Z. Hu, 11/24/2020, switch M06 to B3LYP for S0_VAC
    #bash $FLOW_TOOLS/scripts/make-com.sh -i=$pdb -r='#p B3LYP/6-31G(d) opt' -c=$CHARGE_PDB -t=$name\_S0_vac -l=$S0_VAC
    # Z. Hu, 03/27/2021, make input for MO_OVERLAP and SP-TDDFT
    # B3LYP
    bash $FLOW_TOOLS/scripts/make-com.sh -i=$pdb -r='#p B3LYP/6-31+G(d,p) td=(NStates=5, 50-50) SCRF=(Solvent=Water) 6D 10F nosymm GFInput' -c=$CHARGE_PDB -ns='CHK' -t=$name\_sp-tddft-b3lyp -l=$SP_TDDFT/b3lyp
    # wB97XD
    bash $FLOW_TOOLS/scripts/make-com.sh -i=$pdb -r='#p wB97XD/6-31+G(d,p) td=(NStates=5, 50-50) SCRF=(Solvent=Water) 6D 10F nosymm GFInput' -c=$CHARGE_PDB -ns='CHK' -t=$name\_sp-tddft-wb97xd -l=$SP_TDDFT/wb97xd
    ## MO_OVERLAP
    #bash $FLOW_TOOLS/scripts/make-com.sh -i=$pdb -r='#p B3LYP/6-31+G(d,p) SCRF=(Solvent=Water)' -c=$CHARGE_PDB -ns='RWF' -t=$name\_sp-dft-solv -l=$SP_DFT/solv
    # -----------------------------------------------------------------------------------------------------------------
    
    echo $lowest >> $SP_DFT_SOLV/lowest-energy-conformers.txt 
    cd $SP_DFT_SOLV/completed/
done

#!/bin/bash
#SBATCH -J least-energy-extractor
#SBATCH -o least-energy-extractor.o
#SBATCH -e least-energy-extractor.e
#SBATCH -N 1                                    
#SBATCH -n 14
#SBATCH --partition=lopez
#SBATCH --constraint=ib
#SBATCH --time=24:00:00
#SBATCH --mail-user=EMAIL
#SBATCH --mail-type=END
#SBATCH --parsable
#SBATCH --dependency=afterany:SP_DFT_ID

# source config and function files
source_config

gen_slurm_report

cd $SP_DFT/completed/

rm $SP_DFT/lowest-energy-conformers.txt
touch $SP_DFT/lowest-energy-conformers.txt


for conf in $UNOPT_PDBS/*_0.pdb; do
	name=$(echo $(basename $conf) | sed "s/_0.pdb//")
        # Z. Hu, include inchi_key for counting the number of conformers
        inchi_key="${name:0:27}"
        conf_num=$(find $UNOPT_PDBS -name $inchi_key*.pdb | wc -l)
	lowest=$(bash $FLOW_TOOLS/scripts/get_lowest_conf_sp-dft.sh $name $conf_num)

    # do not create input files if all conformers are not optimized
    if [[ $lowest -eq -1 ]]; then
        continue
    fi

	output_file="$lowest\_sp.log"
	to_all_logs $output_file
	pdb=$lowest.pdb
	cd $RM1_D/opt_pdbs/

        # Z. Hu, Do singlet-point TD-DFT using DFT-optimized geometry
	# make single-point TD-DFT .com file and move to sp_td-dft directory
        # Z. Hu, PDT stage1, do 5 singlet and 5 triplet excited states
	#bash $FLOW_TOOLS/scripts/make-com.sh -i=$pdb -r='#p M06/6-31+G(d,p) td=(NStates=5, 50-50) SCRF=(Solvent=Acetonitrile)' -c=$CHARGE_PDB -t=$name\_sp-tddft -l=$SP_TDDFT
        # Z. Hu, use new functionals wB97XD and water as the solvent
	#bash $FLOW_TOOLS/scripts/make-com.sh -i=$pdb -r='#p wB97XD/6-31+G(d,p) td=(NStates=5, 50-50) SCRF=(Solvent=Water)' -c=$CHARGE_PDB -t=$name\_sp-tddft -l=$SP_TDDFT

        # make DFT S0 optimization .com file and move to dft_opt_s0 directory
	bash $FLOW_TOOLS/scripts/make-com.sh -i=$pdb -r='#p M06/6-31+G(d,p) opt' -t=$name\_S0_vac -l=$S0_VAC
	
	echo $lowest >> $SP_DFT/lowest-energy-conformers.txt 
	cd $SP_DFT/completed/
done

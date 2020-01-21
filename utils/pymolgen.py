import os
import sys

import openbabel
from tqdm import tqdm
from rdkit import Chem
from rdkit.Chem import AllChem
from rdkit.Chem import Draw
from rdkit import rdBase
from itertools import chain
rdBase.DisableLog('rdApp.warning')

"""
This is a script which substitutes a given core molecule with the standard set
of spacers and linkers developed by Biruk Abreha and Steven Lopez. The script
will perform substituions on the core at position indicated using Uranium (U).
The conformers are written to PDB files in a folder named after the given
molecule name.

USAGE: python mol_gen.py molecule_name smiles
"""

# validate inputs
try:
    molecule_name = sys.argv[1]
except:
    print("Please specify a molecule name and a SMILES string.")
    exit()
try:
    parent_smiles = sys.argv[2]
except:
    print("Please specify a SMILES string.")
    exit()

parent_mol = Chem.MolFromSmiles(parent_smiles)
if not parent_mol:
    print("Invalid SMILES string provided.")
    exit()

# reaction SMILES for linkers
linker_rxns = {'unsubstituted': '[*:1]([U])>>[*:1]([H])',
               'benzene': '[*:1]([U])>>[*:1](c2ccc([Y])cc2)',
               'pyridine': '[*:1]([U])>>[*:1](c2ncc([Y])cc2)',
               'pyrimidine': '[*:1]([U])>>[*:1](c2ncc([Y])cn2)',
               'tetrazine': '[*:1]([U])>>[*:1](c2nnc([Y])nn2)',
               'cyclopentadiene': '[*:1]([U])>>[*:1]C2=CC=C([Y])C2',
               'pyrrole (2,5)': '[*:1]([U])>>[*:1](c2ccc([Y])N2)',
               'pyrrole (2,4)': '[*:1]([U])>>[*:1](c2cc([Y])cN2)',
               'pyrrole(N-methyl)': '[*:1]([U])>>[*:1](c2ccc([Y])N(C)2)',
               'pyrrole(N-COH)': '[*:1]([U])>>[*:1](c2ccc([Y])N(C=O)2)',
               'imidazole': '[*:1]([U])>>[*:1](c1cnc([Y])N1)',
               'furan': '[*:1]([U])>>[*:1]c2ccc([Y])O2',
               'thiophene': '[*:1]([U])>>[*:1]c2ccc([Y])S2',
               'thiophene(dioxide)': '[*:1]([U])>>[*:1](c2ccc([Y])S(=O)(=O)2)',
               'thiazole (2,5)': '[*:1]([U])>>[*:1](c2sc([Y])cn2)',
               'thiazole (2,4)': '[*:1]([U])>>[*:1](c2scc([Y])n2)',
               'oxazole (2,5)': '[*:1]([U])>>[*:1](c1ncc([Y])o1)',
               'oxazole (2,4)': '[*:1]([U])>>[*:1](c1nc([Y])co1)',
               'acetylene': '[*:1]([U])>>[*:1](C#C([Y]))',
               'ethylene(trans)': '[*:1]([U])>>[*:1]/C=C(/[Y])',
               'imine': '[*:1]([U])>>[*:1](/C=N(/[Y]))'}

# placeholder for linker addition
linker_place_holder = '[#6:1]([U])'
linker_place_holder_mol = Chem.MolFromSmarts(linker_place_holder)

# append linkers to parent molecule to generate unsubstituted cores
unsubstituted_cores = []
place_holder_count = len(
    parent_mol.GetSubstructMatches(linker_place_holder_mol))
for linker in linker_rxns:
    rxn = AllChem.ReactionFromSmarts(linker_rxns[linker])
    core = parent_mol
    for i in range(place_holder_count):
        new_mols = list(chain.from_iterable(rxn.RunReactants((core,))))
        core = new_mols[0]
    unsubstituted_cores.append(core)


# reaction SMILES for terminal groups
terminal_rxns = {'hydrogen': '[*:1]([Y])>>[*:1]([H])',
                 'hydroxy': '[*:1]([Y])>>[*:1]([OH])',
                 'methoxy': '[*:1]([Y])>>[*:1][O][C]',
                 'trifluoromethoxy': '[*:1]([Y])>>[*:1][O][C](F)(F)F',
                 'trifluoromethyl': '[*:1]([Y])>>[*:1][C](F)(F)F',
                 'methyl': '[*:1]([Y])>>[*:1][C]',
                 'nitro': '[*:1]([Y])>>[*:1][N+]([O-])=O',
                 'thiol': '[*:1]([Y])>>[*:1]([SH])',
                 'fluoro': '[*:1]([Y])>>[*:1][F]',
                 'chloro': '[*:1]([Y])>>[*:1][Cl]',
                 'cyano': '[*:1]([Y])>>[*:1]C#N'}

substituent_place_holder = '[*:1]([Y])'
substituent_place_holder_mol = Chem.MolFromSmarts(substituent_place_holder)

# append terminal groups
all_mols = []
for core in unsubstituted_cores:
    place_holder_count = len(
        core.GetSubstructMatches(substituent_place_holder_mol))
    if place_holder_count == 0:
        all_mols.append(core)
        continue
    for terminal in terminal_rxns:
        new_mol = core
        rxn = AllChem.ReactionFromSmarts(terminal_rxns[terminal])
        for i in range(place_holder_count):
            new_mols = list(chain.from_iterable(rxn.RunReactants((new_mol,))))
            new_mol = new_mols[0]
            Chem.Cleanup(new_mol)
        all_mols.append(Chem.MolFromSmiles(Chem.MolToSmiles(new_mol)))

# canonicalize smiles to remove duplicates
all_mols = [Chem.MolFromSmiles(smiles) for smiles in [
    Chem.MolToSmiles(mol) for mol in all_mols]]
all_smiles = list(set([Chem.MolToSmiles(mol) for mol in all_mols]))

# create directory to store molecules
if not os.path.exists(molecule_name):
    os.makedirs(molecule_name)
out_folder = os.path.abspath(molecule_name)

# write list of SMILES to text file
with open(os.path.join(out_folder, molecule_name + ".txt"), "w") as f:
    for smiles in all_smiles:
        f.write(smiles + "\n")

# lists for tracking conformer generation
good_conformers = []
no_rotatable_bonds = []
no_conformers = []
for smile in tqdm(all_smiles, desc="Generating conformers..."):
    mol = Chem.AddHs(Chem.MolFromSmiles(smile))

    num_rotatable_bonds = AllChem.CalcNumRotatableBonds(mol)

    if num_rotatable_bonds == 0:
        target_num_confs = 1
    else:
        target_num_confs = 4

    # generate conformers
    num_generated_confs = 0
    rms_threshold = 0.25

    while num_generated_confs < target_num_confs and rms_threshold > 0:
        confs = AllChem.EmbedMultipleConfs(mol, numConfs=target_num_confs, maxAttempts=0, randomSeed=-1, clearConfs=True,
                                           useRandomCoords=True, boxSizeMult=2.0, randNegEig=True, numZeroFail=1,
                                           pruneRmsThresh=rms_threshold, coordMap={}, forceTol=0.001, ignoreSmoothingFailures=False,
                                           enforceChirality=True, numThreads=1, useExpTorsionAnglePrefs=True,
                                           useBasicKnowledge=False, printExpTorsionAngles=False)
        num_generated_confs = len(confs)
        rms_threshold -= 0.01

    # track number of successfully generated conformers
    if num_generated_confs == 0:
        no_conformers.append(smile)
        continue
    elif num_generated_confs == 1:
        no_rotatable_bonds.append(smile)
    else:
        good_conformers.append(smile)

    # write conformers to PDB files
    inchi_key = Chem.InchiToInchiKey(Chem.MolToInchi(mol))
    for conf_id in range(num_generated_confs):
        conf_name = f"{inchi_key}_{conf_id}.pdb"
        pdb_file = os.path.join(out_folder, conf_name)
        pdb_writer = Chem.PDBWriter(pdb_file)
        pdb_writer.write(mol, conf_id)
        pdb_writer.close()

# Report on conformer generation results
total_num_confs = len(no_rotatable_bonds) + len(good_conformers) * 4
print(f"Successfully generated {total_num_confs} conformer(s).")
if no_rotatable_bonds:
    print(
        f"Generated one conformer for {len(no_rotatable_bonds)} molecule(s) with no rotatable bonds.")
if no_conformers:
    print(
        f"Failed to generate conformers for {len(no_conformers)} molecule(s).")

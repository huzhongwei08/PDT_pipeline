#! /usr/bin/env python

import os
from rdkit import Chem
from argparse import ArgumentParser, RawDescriptionHelpFormatter

parser = ArgumentParser(formatter_class=RawDescriptionHelpFormatter)
parser.add_argument('file', help='The *pdb file to read.')
args = parser.parse_args()

mol = Chem.rdmolfiles.MolFromPDBFile(args.file)
charge = Chem.rdmolops.GetFormalCharge(mol)
print (charge)

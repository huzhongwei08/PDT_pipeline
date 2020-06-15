#! /usr/bin/env python

import os
import argparse
from rdkit import Chem

files = os.listdir('.')
for file in files:
    if file[-4:] == '.pdb':
       mol = Chem.rdmolfiles.MolFromPDBFile(file)
       charge = Chem.rdmolops.GetFormalCharge(mol)
       print (charge)
       break

"""
Scripts and library for calculating overlap of 2 orbitals
This is intended for evaluating whether a molecule is likely to have a small S1-T1 gap,
but can be used for working with cube files in general.
"""

import numpy as np
import sys
import os
import itertools


def read_cube(cubefile):
    # read cube file into flattened numpy array
    # TODO: format and return voxels and geometry
    with open(cubefile, "r") as f:
        lines = f.readlines()

    #mo_num = lines[0].split()[3]
    #mo_energy = lines[0].split()[-1]
    #voxels = lines[2:6]
    xyz_list = []
    i = 6
    while True:  #  iterate until condition is met. If it's not met, there is a problem anyway
        spline = lines[i].split()
        if len(spline) == 5 or len(spline) == 2: # ==2 is needed for Gaussian outputs (number of HOMO or LUMO)
            xyz_list.append(spline)
            i += 1
        elif len(spline) > 5:
            cube_start = i
            break

    mo_list2d = [i.split() for i in lines[cube_start:]]
    flattened = [float(item) for sublist in mo_list2d for item in sublist]
    return np.array(flattened)


def calc_abs_overlap(m1, m2):
    # calculate overlap of normalized abs(wavefunction)
    m1_norm = np.dot(m1,m1)**0.5
    m2_norm = np.dot(m2,m2)**0.5
    overlap = np.dot(np.abs(m1), np.abs(m2))/(m1_norm*m2_norm)
    return overlap


def calc_all_abs_overlap(indir):
    # TODO: function not complete
    mos = {}
    for subdir in os.listdir(indir):
        subdir_path = os.path.join(indir,subdir)
        mos[subdir] = {}
        for qfile in os.listdir(subdir_path):
            mos[subdir][qfile] = read_cube(os.path.join(subdir_path, qfile))
    print(mos)


if __name__ == "__main__":

    # Read 2 orbitals and calculate their overlap
    mfile_1 = sys.argv[1]
    mfile_2 = sys.argv[2]
    m1 = np.array(read_cube(mfile_1))
    m2 = np.array(read_cube(mfile_2))

    m1_norm = np.dot(m1,m1)**0.5
    m2_norm = np.dot(m2,m2)**0.5
    print("Oribtal 1 norm:", m1_norm)
    print("Orbital 2 norm:", m2_norm)
    overlap = np.dot(np.abs(m1), np.abs(m2))/(m1_norm*m2_norm)
    print("Overlap:", overlap)

import subprocess
import json
import os
import re
from enum import Enum
from tqdm import tqdm
import pandas as pd

# sript for extracting data
def upsearch(dir):
    curdir = os.getcwd()
    while os.getcwd() != "/":
        cwd = os.getcwd()
        if dir in os.listdir(cwd):
            found_dir = os.path.abspath(dir)
            break
        else:
            os.chdir("..")
    try:
        return found_dir
    except:
        raise Exception("Error: directory '{}' not found".format(dir))
    finally:
        os.chdir(curdir)

# change to the main flow directory
cwd = os.getcwd()
flow_dir = os.path.dirname(upsearch("flow-tools"))
os.chdir(flow_dir)

mols = []

for file in os.listdir("unopt_pdbs"):
    if file.endswith("_0.pdb"):
        mols.append(file[:-6])

os.chdir("all-logs")

# function which extracts coordinates from log file
def get_geom(log):
    mol_info = []
    collect_info = False
    try:
        with open(log, "r") as file:
            for line in file:
                line = line.strip()
                if "Dipole" in line:
                    collect_info = False
                elif line.startswith("1\\1\\"):
                    collect_info = True
                    mol_info.append(line)
                elif collect_info:
                    mol_info.append(line)
        mol_info = "".join(mol_info)
        mol_info = mol_info.split("Version", 1)[0]
        mol_info = mol_info.split("\\\\")
        geom = mol_info[3]
        geom = geom.split("\\")[1:]
        return geom
    except:
        return ""


# function which writes xyz files
def write_xyz(name, geom):
    if len(geom) > 0:
        xyz_file = "../mol-data/" + name
        formatted_xyz = ""
        with open(xyz_file, "w") as file:
            file.write(str(len(geom)) + "\n\n")
        for atom in geom:
            formatted_atom = atom.replace(",", "        ")
            formatted_xyz += formatted_atom + "\n"
        with open(xyz_file, "a") as file:
            file.write(formatted_xyz)


# function which extracts basic molecular data
def basic_info(mol):
    cmd = "obprop " + mol + " 2>/dev/null" + " | awk \'{if ($1==\"formula\" || $1==\"mol_weight\" || $1==\"exact_mass\" || $1==\"canonical_SMILES\" || $1==\"InChI\" || $1==\"logP\") print $2 }\'"
    ps = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    output = str(ps.communicate()[0], "utf-8")
    if "Open Babel Warning" in output:
        output = [""] * 10
    else:
        output = output.strip().split("\n")
    # [formula, mol_weight, exact_mass, SMILES, InChI, logP]
    return (output)


# function which extracts energies from given log file
def get_energies(mol):

    def ha_2_eV(ha):
        return str(27.2114 * float(ha))

    try:
        virt_orbs = []
        with open(mol, "r") as file:
            for line in file:
                line = line.strip()
                # free energy
                if line.startswith("Sum of electronic and thermal Free Energies="):
                    free_energy = ha_2_eV(line.split("Energies=")[1].strip())
                # enthalpy
                if line.startswith("Sum of electronic and thermal Enthalpies="):
                    enthalpy = ha_2_eV(line.split("Enthalpies=")[1].strip())
                # entropy
                if line.startswith("KCal/Mol"):
                    entropy = next(file).strip().split(" ")[-1]
                # zpve
                if line.startswith("Sum of electronic and zero-point Energies="):
                    zpve = ha_2_eV(line.split("Energies=")[1].strip())
                # homo
                if line.startswith("Alpha  occ. eigenvalues"):
                    homo = ha_2_eV(line.split(" ")[-1])
                # lumo
                if line.startswith("Alpha virt. eigenvalues"):
                    virt_orbs.append(line)
                # zpve_correction
                if line.startswith("Zero-point correction="):
                    zpve_corr = ha_2_eV(line.split(" ")[-2].strip())
        lumo = ha_2_eV(virt_orbs[0].split("--", 1)[1].strip().split(" ", 1)[0])

        return free_energy, enthalpy, entropy, zpve, homo, lumo, zpve_corr
    except:
        return "", "", "", "", "", "", ""


def get_scf_energy(mol, td=False):
    try:
        scf_energy = ""
        with open(mol, "r") as file:
            for line in file:
                line = line.strip()
                if not td:
                    if line.startswith("SCF Done:"):
                        scf_energy = line.split(" ")[6].strip()
                else:
                    if line.startswith("Total Energy, E(TD-HF/TD-DFT)"):
                        scf_energy = line.split(" ")[-1].strip()
        try:
            return str(27.2114 * float(scf_energy))
        except:
            return scf_energy
    except:
        return ""


def push_data(state, solv, geom, energies, json_obj, total_electronic_energy, fmo=False):
    json_obj[state][solv]["geom"] = geom
    json_obj[state][solv]["energies"]["G"] = energies[0]
    json_obj[state][solv]["energies"]["H"] = energies[1]
    json_obj[state][solv]["energies"]["S"] = energies[2]
    json_obj[state][solv]["energies"]["zpve"] = energies[3]
    json_obj[state][solv]["energies"]["total_electronic_energy"] = total_electronic_energy
    if fmo:
        json_obj[state][solv]["energies"]["homo"] = energies[4]
        json_obj[state][solv]["energies"]["lumo"] = energies[5]

# extract data for each molecule
for mol in tqdm(mols, desc="Extracting data..."):
	# filename
    s1_solv_opt = mol + "_S1_solv.log"
    s1_solv_freq = mol + "_S1_solv_freq.log"
    s1_solv_xyz = mol + "_S1_solv.xyz"
    s0_vac_opt = mol + "_S0_vac.log"
    s0_vac_freq = mol + "_S0_vac_freq.log"
    s0_vac_xyz = mol + "_S0_vac.xyz"
    s0_solv_opt = mol + "_S0_solv.log"
    s0_solv_freq = mol + "_S0_solv_freq.log"
    s0_solv_xyz = mol + "_S0_solv.xyz"
    cat_rad_vac_opt = mol + "_cat-rad_vac.log"
    cat_rad_vac_freq = mol + "_cat-rad_vac_freq.log"
    cat_rad_vac_xyz = mol + "_cat-rad_vac.xyz"
    cat_rad_solv_opt = mol + "_cat-rad_solv.log"
    cat_rad_solv_freq = mol + "_cat-rad_solv_freq.log"
    cat_rad_solv_xyz = mol + "_cat-rad_solv.xyz"
    t1_solv_opt = mol + "_T1_solv.log"
    t1_solv_freq = mol + "_T1_solv_freq.log"
    t1_solv_xyz = mol + "_T1_solv.xyz"
    sp_tddft = mol + "_sp-tddft.log"
    t1_sp_tddft = mol + "_t1_sp-tddft.log"

    # get basic mol info
    mol_data = basic_info("../unopt_pdbs/" + mol + "_0.pdb")

	# dipole moment (ground state)
    dipole_moment_s0 = ""
    try:
        with open(s0_solv_freq, "r") as file:
            for line in file:
                line = line.strip()
                if line.startswith("X="):
                    dipole_moment_s0 = line.split("Tot=")[1].strip()
                    break
    except:
        pass
	
	# dipole moment (S1 state)
    dipole_moment_s1 = ""
    try:
        with open(s1_solv_freq, "r") as file:
            for line in file:
                line = line.strip()
                if line.startswith("X="):
                    dipole_moment_s1 = line.split("Tot=")[1].strip()
                    break
    except:
        pass


    # dipole moment (T1 state)
    dipole_moment_t1 = ""
    try:
        with open(t1_solv_freq, "r") as file:
            for line in file:
                line = line.strip()
                if line.startswith("X="):
                    dipole_moment_t1 = line.split("Tot=")[1].strip()
                    break
    except:
        pass

    # vertical excitation energy (S1)
    vertical_excitation_energy_s1 = ""
    try:
        with open(s1_solv_opt, "r") as file:
            for line in file:
                line = line.strip()
                if line.startswith("Excited State   1:"):
                    vertical_excitation_energy_s1 = line.split("eV", 1)[0].strip().split(" ")[-1].strip()
                    break
    except:
        try:
            with open(sp_tddft, "r") as file:
                for line in file:
                    line = line.strip()
                    if line.startswith("Excited State   1:"):
                        vertical_excitation_energy_s1 = line.split("eV", 1)[0].strip().split(" ")[-1].strip()
                        break
        except:
            pass

    # extract energies
    s1_solv_energies = get_energies(s1_solv_freq)
    s0_vac_energies = get_energies(s0_vac_freq)
    s0_solv_energies = get_energies(s0_solv_freq)
    cat_rad_vac_energies = get_energies(cat_rad_vac_freq)
    cat_rad_solv_energies = get_energies(cat_rad_solv_freq)
    t1_solv_energies = get_energies(t1_solv_freq)

    # electronic energies
    s0_vac_elec_energy = get_scf_energy(s0_vac_opt)
    s0_solv_elec_energy = get_scf_energy(s0_solv_opt)
    s1_solv_elec_energy = get_scf_energy(s1_solv_opt, td=True)
    cat_rad_vac_elec_energy = get_scf_energy(cat_rad_vac_opt)
    cat_rad_solv_elec_energy = get_scf_energy(cat_rad_solv_opt)
    t1_solv_elec_energy = get_scf_energy(t1_solv_opt)

    # extract geometries
    s0_vac_geom = get_geom(s0_vac_opt)
    s0_solv_geom = get_geom(s0_solv_opt)
    s1_solv_geom = get_geom(s1_solv_opt)
    t1_solv_geom = get_geom(t1_solv_opt)
    cat_rad_vac_geom = get_geom(cat_rad_vac_opt)
    cat_rad_solv_geom = get_geom(cat_rad_solv_opt)

    # write xyz files
    write_xyz(s0_vac_xyz, s0_vac_geom)
    write_xyz(s0_solv_xyz, s0_solv_geom)
    write_xyz(s1_solv_xyz, s1_solv_geom)
    write_xyz(t1_solv_xyz, t1_solv_geom)
    write_xyz(cat_rad_vac_xyz, cat_rad_vac_geom)
    write_xyz(cat_rad_solv_xyz, cat_rad_solv_geom)

    # COMPUTE PROPERTIES
    # S1 0-0 transition energy
    if (s0_solv_energies[6] != "") and (s1_solv_energies[6] != "") and (s1_solv_elec_energy != "") and (s0_solv_elec_energy != ""):
        delZPVE_eV = float(s0_solv_energies[6]) - float(s1_solv_energies[6])
        adiabatic_energy_eV = float(s1_solv_elec_energy) - float(s0_solv_elec_energy)
        E00_S1 = round(adiabatic_energy_eV - delZPVE_eV,2)
    else:
        E00_S1 = ""

    # T1 0-0 transition energy
    if (s0_solv_energies[6] != "") and (t1_solv_energies[6] != "") and (t1_solv_elec_energy != "") and (s0_solv_elec_energy != ""):
        delZPVE_eV = float(s0_solv_energies[6]) - float(t1_solv_energies[6])
        adiabatic_energy_eV = float(t1_solv_elec_energy) - float(s0_solv_elec_energy)
        E00_T1 = round(adiabatic_energy_eV - delZPVE_eV,2)
    else:
        E00_T1 = ""

    # ionization potential
    if (s0_vac_energies[1] != "") and (cat_rad_vac_energies[1] != ""):
        ip = round(float(cat_rad_vac_energies[1]) - float(s0_vac_energies[1]), 2)
    else:
        ip = ""

    # oxidation potential
    if "" not in (ip, s0_vac_energies[2], cat_rad_vac_energies[2], s0_solv_energies[0], 
                  s0_vac_energies[0], cat_rad_solv_energies[0], cat_rad_vac_energies[0]):
        # delta_S
        s0_S = float(s0_vac_energies[2]) / 1000
        cat_rad_S = float(cat_rad_vac_energies[2]) / 1000
        delS = float(cat_rad_S) - float(s0_S)
        TdelS = -298.15 * delS
        # ox solvation energy
        s0_solvation_energy = 23.0605 * (float(s0_solv_energies[0]) - float(s0_vac_energies[0]))
        # red solvation energy
        cat_rad_solvation_energy = 23.0605 * (float(cat_rad_solv_energies[0]) - float(cat_rad_vac_energies[0]))

        ox_pot = round(ip + (1 / 23.06) * (TdelS + cat_rad_solvation_energy - s0_solvation_energy) - 4.44, 2)
    else:
        ox_pot = ""
    # reduction potential
	# TODO: compute reduction potential, then use result to compute excited state reduction potential
    # still needs radical anion calculation to compute

    # excited state oxidation potentials (vs NHE)
    if ox_pot != "":
		# S1 oxidation potential
        if E00_S1 != "":
            ox_pot_s1 = round(ox_pot - E00_S1, 2)
        else:
            ox_pot_s1 = ""
        # T1 oxidation potential
        if E00_T1 != "":
            ox_pot_t1 = round(ox_pot - E00_T1, 2)
        else:
            ox_pot_t1 = ""
    else:
        ox_pot_s1 = ""
        ox_pot_t1 = ""

    # write data
    flow_dir = os.environ['FLOW']
    with open(flow_dir + "/templates/mol-template.json", "r+") as file:
        data = json.load(file)

        # basic details
        data["formula"] = mol_data[0]
        data["smiles"] = mol_data[3]
        data["inchi"] = mol_data[4]
        data["inchi-key"] = mol

        # properties
        data["properties"]["mw"] = mol_data[1]
        data["properties"]["ip"] = str(ip)
        data["properties"]["rp"] = str(ox_pot)
        data["properties"]["0-0_S1"] = str(E00_S1)
        data["properties"]["0-0_T1"] = str(E00_T1)
        data["properties"]["vee"] = vertical_excitation_energy_s1
        data["properties"]["dipole_moment_s0"] = dipole_moment_s0
        data["properties"]["dipole_moment_s1"] = dipole_moment_s1
        data["properties"]["dipole_moment_t1"] = dipole_moment_t1
        data["properties"]["oxidation_potential_s1"] = str(ox_pot_s1)
        data["properties"]["oxidation_potential_t1"] = str(ox_pot_t1)

        # S0 solv
        push_data("s0", "solv", s0_solv_geom, s0_solv_energies, data, s0_solv_elec_energy, fmo=True)
        # S0 vac
        push_data("s0", "vac", s0_vac_geom, s0_vac_energies, data, s0_vac_elec_energy, fmo=True)
        # S1 solv
        push_data("s1", "solv", s1_solv_geom, s1_solv_energies, data, s1_solv_elec_energy)
        # cation radical solv
        push_data("cat-rad", "solv", cat_rad_solv_geom, cat_rad_solv_energies, data, cat_rad_solv_elec_energy)
        # cation radical vac
        push_data("cat-rad", "vac", cat_rad_vac_geom, cat_rad_vac_energies, data, cat_rad_vac_elec_energy)
        # T1 solv
        push_data("t1", "solv", t1_solv_geom, t1_solv_energies, data, t1_solv_elec_energy)

    json_name = mol + ".json"

    with open("../mol-data/" + json_name, "w") as data_file:
        data_file.write(json.dumps(data, indent=4))

os.chdir(cwd)

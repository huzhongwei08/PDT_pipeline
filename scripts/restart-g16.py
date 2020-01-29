import os
import sys
import glob
import re
import numpy as np

cwd = os.getcwd()
files = [file for file in sys.argv[1:] if file.endswith(".com")]
com_files = []

# only keep input files which also have log files in the same directory
for file in files:
    if os.path.exists(file.replace(".com", ".log")):
        com_files.append(file)

# returns the route of the given Gaussian input file
def get_route(com_file):
    route = None
    with open(com_file, "r") as file:
        for line in file:
            line = line.strip()
            if line.startswith("#"):
                route = line
                break
    return route

# returns the options of the opt keyword
def get_opt_options(route):
    opt_keyword = get_opt_keyword(route)
    try:
        opt_options = opt_keyword.split("=", 1)[1].replace(")", "").replace("(", "").split(",")
        return opt_options
    except:
        return []

# returns the opt keyword
def get_opt_keyword(route):
    opt_keyword = [i for i in route.split(" ") if i.startswith("opt")][0]
    return opt_keyword

# returns the number of occurences of the given search string in the given file
def get_count(file, search_string):
    text = open(file, "r").read()
    count = text.count(search_string)
    return count

# returns a list of SCF energies from the given opt log file
def get_SCF_energies(log_file):
    energies = []
    with open(log_file, "r") as f:
        for line in f:
            line = line.strip()
            if line.startswith("SCF Done:"):
                energies.append(float(line.split("=")[1].split('A.U.')[0].strip()))
    return energies

# determines if the SCF energy is oscillating 
def is_opt_oscillating(log_file):
    energy_diffs = np.diff(get_SCF_energies(log_file))
    energy_stdev = np.std(energy_diffs)
    if energy_stdev >= 0.001:
        return True
    else:
        return False

# determines if the given job needs to be restarted
def needs_restart(com_file, log_file):
    route = get_route(com_file)
    normal_t_count = get_count(log_file, "Normal termination")
    if "opt" in route and "freq" in route:
        if normal_t_count == 2:
            return False
    elif "opt" in route or "freq" in route or "# Restart" in route:
        if normal_t_count == 1:
            return False
    return True

# determines if the given job encountered an error fail
def error_fail(log_file):
    return get_count(log_file, "Error termination") > 0

# determines if the given job encountered a link 9999 failure
def link_9999_fail(log_file):
    return get_count(log_file, "Error termination request processed by link 9999.") > 0

# determines if the given job failed due to a convergence failure
def convergence_fail(log_file):
    return get_count(log_file, "Convergence failure -- run terminated.") > 0

# determines if the given job failed due to a FormBX failure
def formbx_fail(log_file):
    return get_count(log_file, "FormBX had a problem.") > 0

# removes the coordinates, charge, and multiplicity from the given Gaussian input file
def remove_coord_charge_mult(com_file):
    file_text = open(com_file, "r").readlines()
    with open(com_file, "w") as file:
        for line in file_text:
            search = re.match(r'-?\d \d', line)
            if search:
                break
            else:
                file.write(line)

# removes repetitive options from opt keyword
def clean_options(opt_options):
    opt_options = [opt.lower() for opt in opt_options]
    opt_options = list(set(opt_options))
    if any([i.startswith("recalcfc") for i in opt_options]) and "calcfc" in opt_options:
        opt_options.remove("calcfc")
    return opt_options

# sets up an optimization to be restarted
def restart_opt(com_file, log_file, additional_opt_options=[]):
    route = get_route(com_file)
    opt_keyword = get_opt_keyword(route)
    opt_options = get_opt_options(route)
    print(opt_options)
    additional_opt_options = [opt.lower() for opt in additional_opt_options]
    print(additional_opt_options)
    opt_options.append("restart")

    opt_options += additional_opt_options
    opt_options = clean_options(opt_options)
    print(opt_options)
    
    oscillating = is_opt_oscillating(log_file)
    if oscillating:
        recalcfc = any([i.startswith("recalcfc") for i in opt_options])
        if "calcfc" not in opt_options and not recalcfc:
            opt_options.append("calcfc")
        if "maxstep=15" not in opt_options:
            opt_options.append("maxstep=15")

    if not oscillating and "opt=" in route and "geom=allcheck" in route and "guess=read" in route:
        return
    else:
        remove_coord_charge_mult(com_file)
        file_text = open(com_file, "r").readlines()
        with open(com_file, "w") as file:
            for line in file_text:
                if line.startswith("#"):
                    line = line.strip()
                    new_opt_keyword = "opt=(" + ",".join(opt_options) + ")"
                    new_line = line.replace(opt_keyword, new_opt_keyword)
                    new_line += " geom=allcheck guess=read\n"
                    file.write(new_line)
                else:
                    file.write(line)

# sets up a frequency calculation to be restarted
def restart_freq(com_file):
    remove_coord_charge_mult(com_file)
    file_text = open(com_file, "r").readlines()
    with open(com_file, "w") as file:
        for line in file_text:
            if line.startswith("#"):
                file.write("# Restart\n")
            else:
                file.write(line)

# Removes the rwf files associated with the given log file
def clear_gau_files(log_file):
    with open(log_file, "r") as file:
        for line in file:
            line = line.strip()
            if line.startswith("Entering Link 1"):
                PID = line.split(" ")[-1].replace(".", "")
                INP_ID = str(int(PID) - 1)
    try:
        for f in glob.glob("Gau-{}*".format(PID)):
            os.remove(f)
    except:
        pass
    try:
        os.remove("Gau-{}.inp".format(INP_ID))
    except:
        pass


cwd = os.getcwd()
files = [file for file in sys.argv[1:] if file.endswith(".com")]
com_files = []

# only keep input files which also have log files in the same directory
for file in files:
    if os.path.exists(file.replace(".com", ".log")):
        com_files.append(file)

for com_file in com_files:
    log_file = com_file.replace(".com", ".log")
    error = error_fail(log_file)
    if needs_restart(com_file, log_file) and not error:
        route = get_route(com_file)
        normal_t_count = get_count(log_file, "Normal termination")
        if "opt" in route and "freq" in route:
            if normal_t_count == 1:
                restart_freq(com_file)
            elif normal_t_count == 0:
                restart_opt(com_file, log_file)
        elif "opt" in route:
            restart_opt(com_file, log_file)
        elif "freq" in route:
            restart_freq(com_file)
            clear_gau_files(log_file)
    elif convergence_fail(log_file) or formbx_fail(log_file):
        restart_opt(com_file, log_file, additional_opt_options=["calcfc"])
        clear_gau_files(log_file)
    elif link_9999_fail(log_file):
        restart_opt(com_file, log_file, additional_opt_options=["recalcfc=4"])
        clear_gau_files(log_file)

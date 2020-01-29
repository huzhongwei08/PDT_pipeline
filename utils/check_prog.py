import os
import sys
import glob
import re
import datetime
import time

def get_prog(directory, num_mols, name, output_type=".log", dft=False, print=True):

    completed_dir = os.path.join(directory, "completed")
    if dft:
        failed_opt_dir = os.path.join(directory, "failed_opt")
        failed_freq_dir = os.path.join(directory, "failed_freq")
        resubmits_dir = os.path.join(directory, "resubmits")
        freq_calcs_dir = os.path.join(directory, "freq_calcs")
        freq_output = f"_freq{output_type}"
    else:
        failed_opt_dir = os.path.join(directory, "failed")

    if dft:
        num_complete = get_num_files(completed_dir, freq_output)
        num_resubmissions = get_num_files(resubmits_dir, output_type)
        num_running = (get_num_files(directory, output_type, last_modified=True) +
                       get_num_files(resubmits_dir, output_type, last_modified=True) +
                       get_num_files(freq_calcs_dir, freq_output, last_modified=True))

    else:
        num_complete = get_num_files(completed_dir, output_type)
        num_running = get_num_files(directory, output_type, last_modified=True)

    if dft:
        num_failed_opt = get_num_files(failed_opt_dir, output_type)
        num_failed_freq = get_num_files(failed_freq_dir, output_type)
    else:
        num_failed_opt = get_num_files(failed_opt_dir, output_type)

    num_incomplete = num_mols - num_complete

    if dft:
        row = [name,
               num_complete, get_formatted_percentage(
                   num_complete, num_mols),
               num_incomplete, get_formatted_percentage(
                   num_incomplete, num_mols),
               num_running, get_formatted_percentage(
                   num_running, num_mols),
               num_resubmissions, get_formatted_percentage(
                   num_resubmissions, num_mols),
               num_failed_opt, get_formatted_percentage(
                   num_failed_opt, num_mols),
               num_failed_freq, get_formatted_percentage(num_failed_freq, num_mols)]
    else:
        row = [name,
               num_complete, get_formatted_percentage(
                   num_complete, num_mols),
               num_incomplete, get_formatted_percentage(
                   num_incomplete, num_mols),
               num_running, get_formatted_percentage(
                   num_running, num_mols),
               "    -------   ",
               num_failed_opt, get_formatted_percentage(
                   num_failed_opt, num_mols),
               "    -------   "]
    if print:
        if dft:
            print_format = "{: >20} {: >5} {: >8} {: >5} {: >8} {: >5} {: >8} {: >5} {: >8} {: >5} {: >8} {: >5} {: >8}"
        else:
            print_format = "{: >20} {: >5} {: >8} {: >5} {: >8} {: >5} {: >8} {: >13} {: >5} {: >8} {: >13}"
        print_formatted(print_format, row)


def get_num_files(directory, output_type, last_modified=False):
    if last_modified:
        all_files = glob.glob(os.path.join(directory, f"*{output_type}"))
        difftime = time.time() - 60
        recently_modified = [f for f in all_files if os.path.getmtime(f) >= difftime]
        return len(recently_modified)
    else:
        return len(glob.glob(os.path.join(directory, f"*{output_type}")))


def get_formatted_percentage(num, denom):
    try:
        percentage = round((num / denom) * 100, 1)
    except ZeroDivisionError as e:
        percentage = 0.0
    return f"({percentage}%)"


def find_flow_dir():
    curdir = os.getcwd()
    while os.getcwd() != "/":
        cwd = os.getcwd()
        if "flow-tools" in os.listdir(cwd):
            flow_dir = os.path.abspath("flow-tools")
            break
        else:
            os.chdir("..")
    try:
        return flow_dir.replace("/flow-tools", "")
    except:
        raise Exception("Error: directory 'flow-tools' not found")
    finally:
        os.chdir(curdir)


def print_formatted(row_format, row):
    print(row_format.format(*row))


def print_header():
    header = ["", "completed", "incomplete", "running",
              "resubmissions", "failed_opt", "failed_freq"]
    header_format = "{: >20} {: >14} {: >14} {: >14} {: >14} {: >14} {: >14}"
    print_formatted(header_format, header)


def print_info(flow_name, num_unique_mols, num_structures):
    now = datetime.datetime.now()
    print(f"\n\t\tReport for '{flow_name.upper()}'")
    print("\t\t" + now.strftime("%a %B %d %H:%M:%S %Z"))
    print(f"\t\tNum. Molecules: {num_unique_mols}")
    print(f"\t\tTotal Num. Structures: {num_structures}\n")


if __name__ == "__main__":
    cwd = os.getcwd()
    try:
        flow_dir = find_flow_dir()
        flow_name = os.path.basename(flow_dir)

        os.chdir(flow_dir)
        confs = glob.glob('unopt_pdbs/*.pdb')
        num_confs = len(confs)
        num_unique_mols = len(
            set([re.sub(r"_\d+.pdb", '', conf) for conf in confs]))

        print_info(flow_name, num_unique_mols, num_confs)
        print("\t\t\t\t\t\t  Pre-DFT Optimization")
        print_header()
        get_prog("pm7", num_confs, "PM7 opt")
        get_prog("rm1-d", num_confs, "RM1-D opt", output_type=".o")
        get_prog("sp-dft", num_confs, "SP-DFT")
        get_prog("sp-tddft", num_unique_mols, "SP-TD-DFT")
        print("\n\t\t\t\t\t\t    DFT Optimization")
        print_header()
        get_prog("s0_vac", num_unique_mols, "S0 (in vacuo)", dft=True)
        get_prog("s0_solv", num_unique_mols, "S0 (in MeCN)", dft=True)
        get_prog("sn_solv", num_unique_mols, "SN (in MeCN)", dft=True)
        get_prog("t1_solv", num_unique_mols, "T1 (in MeCN)", dft=True)
        get_prog("cat-rad_vac", num_unique_mols,
                 "cat-rad (in vacuo)", dft=True)
        get_prog("cat-rad_solv", num_unique_mols,
                 "cat-rad (in MeCN)", dft=True)
        print()
    except:
        print("Error: Unable to find flow directory. Ensure that you are in a flow directory prior to running this script.")
    finally:
        os.chdir(cwd)

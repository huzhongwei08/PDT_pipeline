#module called by soc.py
#general control for spin-orbit coupling calculation

import sys
#control parameter
QM_ex_flag = False #False we do QM calculation separately
QM_code = 'gauss_tddft' # gauss_tddft or tddftb
n_s = [1, 2, 3, 4, 5] #default # of excited singlets
n_t = [1, 2, 3, 4, 5] #default # of excited triplets
n_g = ['True']       #default including ground state
soc_scal = 1.0 #scaling factor for Zeff in SOC operator
cicoeff_thresh = [1.0e-5] #thresh hold for ci coeff 

# environmental variable
g16root = '/shared/centos7/gaussian-B01'
sys.path.append(g16root+'/g16')

##molsoc code from Sandro Giuseppe Chiodo
##with small modifications for input because only the soc
##in atomic basis is needed in the following calculation 
molsoc_path = './molsoc0.1.exe'

#input files

if QM_code == 'gauss_tddft':
##from Gaussian output
   qm_out = ['gaussian.log', 'gaussian.rwf']
   geom_xyz = []
   soc_key  = ['ANG', 'Zeff', 'DIP']
elif QM_code == 'tddftb':
##from TD-DFTB+ output
   qm_out = ['band.out', 'EXC.DAT', 'oversqr.dat', 'eigenvec.out', \
             'XplusY.DAT', 'SPX.DAT']
   geom_xyz = ['dty.xyz']
   soc_key  = ['ANG', 'Zeff', 'DIP', 'TDB']
##input for molsoc(to be generated) 
molsoc_input = ['molsoc.inp', 'molsoc_basis']

%chk=benzene_pdb.chk
%rwf=benzene_pdb.rwf
%NoSave
%mem=8GB
%nproc=16
# b3lyp/tzvp opt

benzene_pdb

0 1
C          -0.76000         1.16900        -0.00100
C           0.63300         1.24500        -0.00100
C           1.39500         0.07700         0.00000
C           0.76400        -1.16800         0.00300
C          -0.62900        -1.24300         0.00000
C          -1.39100        -0.07500        -0.00200
H          -1.35400         2.07900         0.00100
H           1.12400         2.21400        -0.00300
H           2.48000         0.13500        -0.00000
H           1.35800        -2.07800         0.00600
H          -1.12000        -2.21300        -0.00000
H          -2.47600        -0.13400        -0.00300


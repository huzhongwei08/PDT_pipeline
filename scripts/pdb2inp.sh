#!/bin/bash

file=$1
gamess_commands=$2

title="${file/.pdb/}"
temp="${file/.pdb/.temp}"
inp="${file/.pdb/.inp}"

obabel -i pdb $file -o inp -O "${file/.pdb/.temp}" &>/dev/null

echo "$(tail -n +4 $temp)" > $temp
cat $gamess_commands >> $inp
cat $temp >> $inp

rm $temp

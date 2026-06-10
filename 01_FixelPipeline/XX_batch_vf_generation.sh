#!/bin/bash
module load mrtrix

# Specify the directory containing the folders
parent_dir="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/subjects"

cd $parent_dir
# Loop through each folder in the parent directory
for_each * : mrconvert -coord 3 0 IN/wmfod.mif - \| mrcat IN/csffod.mif IN/gmfod.mif - IN/vf.mif
#mrview IN/vf.mif -odf.load_sh IN/wmfod.mif


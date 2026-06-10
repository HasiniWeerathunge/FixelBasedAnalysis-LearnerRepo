#!/bin/bash
module load mrtrix

# Specify the directory containing the folders
parent_dir="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/subjects_cohort1"

cd $parent_dir
# Loop through each folder in the parent directory
for_each * : dwi2response dhollander IN/dwi.mif IN/response_wm.txt IN/response_gm.txt IN/response_csf.txt


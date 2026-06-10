#!/bin/bash

module load mrtrix
# Specify the directory containing the folders
parent_dir="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/subjects"

cd $parent_dir
# Loop through each folder in the parent directory
#for_each * : mrgrid IN/dwi.mif regrid -vox 1.25 IN/dwi_upsampled.mif
#for_each * : dwi2mask IN/dwi_upsampled.mif IN/dwi_mask_upsampled.mif
for_each * : mrgrid IN/mask.mif regrid -vox 1.25 IN/mask_upsampled.mif

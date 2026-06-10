#!/bin/bash
module load mrtrix
# Specify the directory containing the folders
parent_dir="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/subjects"

cd $parent_dir

# Joint Bias field correction and intensity normalization 

       
for_each -nthreads 16 * : mtnormalise IN/wmfod.mif IN/wmfod_norm.mif IN/gmfod.mif IN/gmfod_norm.mif IN/csffod.mif IN/csffod_norm.mif -mask IN/dwi_mask_upsampled.mif
    

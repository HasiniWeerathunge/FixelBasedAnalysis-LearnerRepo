#!/bin/bash
module load mrtrix
# Specify the directory containing the folders
parent_dir="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/subjects"

cd $parent_dir

# Generate a study-specific unbiased FOD template
	#1. Select a subset of participants n = 20 from each group (CT,CWS)
	#2. Make template directory  and input all FOD inputs and corresponding mask images of those participants 
	#3. symbolic link all FOD images (and masks) into a single input folder
	#4.  run the template building script

mkdir -p ../template/fod_input
mkdir ../template/mask_input

#for_each `ls -d SF[0-9][0-9][0-9]_1 |sort -g | tail -10` : ln -sr IN/wmfod_norm.mif ../template/fod_input/PRE.mif ";" ln -sr IN/dwi_mask_upsampled.mif ../template/mask_input/PRE.mif

#for_each `ls -d SM[0-9][0-9][0-9]_1 |sort -g | tail -10` : ln -sr IN/wmfod_norm.mif ../template/fod_input/PRE.mif ";" ln -sr IN/dwi_mask_upsampled.mif ../template/mask_input/PRE.mif

#for_each `ls -d NF[0-9][0-9][0-9]_1 |sort -g | tail -10` : ln -sr IN/wmfod_norm.mif ../template/fod_input/PRE.mif ";" ln -sr IN/dwi_mask_upsampled.mif ../template/mask_input/PRE.mif

#for_each `ls -d NM[0-9][0-9][0-9]_1 |sort -g | tail -10` : ln -sr IN/wmfod_norm.mif ../template/fod_input/PRE.mif ";" ln -sr IN/dwi_mask_upsampled.mif ../template/mask_input/PRE.mif

# to use the full population
for_each * : ln -sr IN/wmfod_norm.mif ../template/fod_input/PRE.mif
for_each * : ln -sr IN/dwi_mask_upsampled.mif ../template/mask_input/PRE.mif

population_template ../template/fod_input -mask_dir ../template/mask_input ../template/wmfod_template.mif -voxel_size 1.25 -nthreads 64 -nocleanup

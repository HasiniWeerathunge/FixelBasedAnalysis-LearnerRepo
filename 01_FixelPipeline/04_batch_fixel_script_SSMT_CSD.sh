#!/bin/bash
module load mrtrix/tissue
# Specify the directory containing the folders
parent_dir="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/subjects"

# Loop through each folder in the parent directory
N = 64
(
for folder in "$parent_dir"/*; do
    ((i=i%N)); ((i++==0)) && wait
    if [ -d "$folder" ]; then
        echo "Processing folder: $(basename "$folder")"
        ss3t_csd_beta1 $folder/dwi_upsampled.mif group_average_response_wm_cohort2.txt $folder/wmfod.mif group_average_response_gm_cohort2.txt $folder/gmfod.mif group_average_response_csf_cohort2.txt $folder/csffod.mif -mask $folder/dwi_mask_upsampled.mif &
    fi
done
)





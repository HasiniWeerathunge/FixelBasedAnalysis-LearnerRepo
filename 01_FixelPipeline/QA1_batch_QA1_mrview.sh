#!/bin/bash
module load mrtrix

# Specify the directory containing the folders
parent_dir="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/subjects"

cd $parent_dir

# Loop through each subject folder in the parent directory
for subject_dir in "$parent_dir"/*/; do
    # Check if the subject folder contains MRtrix3 image files
    if [ -d "$subject_dir" ]; then
        # Loop through each file in the subject folder
        for file in "$subject_dir"/dwi_mask_upsampled.mif; do
            # Check if the file is a valid MRtrix3 image file (e.g., .mif)
            if [ -f "$file" ]; then
                # Open the file in mrview
                mrview "$file" 
		# Wait for user input before proceeding to the next file
    		read -p "Press Enter to open the next image file"
            fi
        done
    fi
done


#!/bin/bash

TARGET_FILE="fixel_in_template_space"


# Specify the directory containing the folders
parent_dir="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/subjects_cohort1"

# Loop through each folder in the parent directory
for folder in "$parent_dir"/*; do
    if [ -d "$folder" ]; then
        echo "Processing folder: $(basename "$folder")"
        # Remove all files except dwi.mif and mask.mif
        find "$folder" -type d -name "$TARGET_FILE" -exec rm -d {} +
	
    fi
done




#!/bin/bash
module load mrtrix/tissue
# Specify the directory containing the folders
parent_dir="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/subjects_subset_NF"
# Define the maximum number of parallel processes
MAX_JOBS=4

# A counter for the number of parallel jobs
job_count=0

# Loop through each folder in the parent directory
for folder in "$parent_dir"/*; do
   
   # Each background job is defined here
    
   {
      echo "Processing item $folder"
      # Replace the following line with the command you wish to run in parallel
      ss3t_csd_beta1 $folder/dwi_upsampled.mif group_average_response_wm.txt $folder/wmfod.mif group_average_response_gm.txt $folder/gmfod.mif group_average_response_csf.txt $folder/csffod.mif -mask $folder/dwi_mask_upsampled.mif
   } &  # The ampersand puts the job in the background

   # Increment the job count
   ((job_count++))

   # Check if we have reached the max number of jobs
   if [[ job_count -ge MAX_JOBS ]]; then
       # Wait for all parallel jobs to finish before continuing
       wait
       job_count=0
   fi
done

# Catch all remaining background jobs if any
wait
echo "All parallel jobs have finished."

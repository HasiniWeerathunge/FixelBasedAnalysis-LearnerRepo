# Specify the directory containing the folders
parent_dir="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/subjects"

# Loop through each folder in the parent directory
for folder in "$parent_dir"/*; do
    if [ -d "$folder" ]; then
        echo "Processing folder: $(basename "$folder")"
        # Remove all files except dwi.mif and mask.mif
        find "$folder" -type f ! -name "dwi.mif" ! -name "mask.mif" ! -name "response_csf.txt" ! -name "response_wm.txt" ! -name "response_gm.txt" ! -name "dwi_mask_upsampled.mif" ! -name "dwi_upsampled.mif" ! -name "mask_upsampled.mif" ! -exec rm -f {} +
	# Remove all subfolders
    	find "$folder" -mindepth 1 -type d -delete
    fi
done




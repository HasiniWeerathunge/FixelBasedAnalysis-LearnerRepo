module load mrtrix
module load afni


# -----------------------------
# Paths 
# -----------------------------
STATS_DIR="stats_log_fc_centered_InteractionGroupAge_negative"

mrthreshold "$STATS_DIR"/fwe_1mpvalue.mif -abs 0.95 "$STATS_DIR"/sigmask_FWE_05.mif  # generate punc<.005 thresholded map
mrcalc "$STATS_DIR"/sigmask_FWE_05.mif 0 -gt "$STATS_DIR"/sigmask_FWE_05_bin.mif           # convert it to binary map

fixel2voxel sigmask_FWE_05_bin.mif mean sigmask_FWE_05_bin_voxel.mif                       # convert it to voxels
mrconvert sigmask_FWE_05_bin_voxel.mif sigmask_FWE_05_bin_voxel.nii                        # convert to nifti format

3dclust -NN3 -1Dformat -savemask clustered_mask.nii.gz sigmask_unc_005_bin_voxel.nii>cluster_stats.1D

for i in $(seq 1 $(3dBrickStat -max clustered_mask.nii.gz)); do 3dcalc -a clustered_mask.nii.gz -expr "equals(a,$i)" -prefix cluster_${i}.nii.gz done


## MNI clusters

3dclust -NN3 -1Dformat -savemask clustered_mask_unc_001_MNI_3dclust.nii.gz sigmask_unc_001_bin_voxel_MNI.nii>cluster_stats.1D


for i in $(seq 1 $(3dBrickStat -max clustered_mask_unc_001_MNI_3dclust.nii.gz)); do 3dcalc -a clustered_mask_unc_001_MNI_3dclust.nii.gz -expr "equals(a,$i)" -prefix cluster_MNI_${i}.nii.gz done




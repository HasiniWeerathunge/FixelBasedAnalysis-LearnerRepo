#!/bin/bash
module load mrtrix
module load AFNI
module load fsl

# -----------------------------
# Paths 
# -----------------------------
TRACT_DIR="tract_based_analysis/fixel_mask_tracts_selected"
STATS_DIR="stats_log_fc_centered_InteractionGroupAge_negative"
OUT_DIR="OVERLAP_metrics/InteractionGroupAge_negative_03312026"
CROPPED_TRACT_DIR="tract_based_analysis/tract_cropped/log_fc_smooth"
FIXEL_DIR="fixel_mask/"
mkdir "$CROPPED_TRACT_DIR/tract_masks"
mkdir -p $OUT_DIR

# declaring arrays
declare -a total_fixels_FWE_cluster
declare -a tract_overlap_FWE_cluster
declare -a percent_FWE_cluster

declare -a total_fixels_unc_cluster
declare -a tract_overlap_unc_cluster
declare -a percent_unc_cluster

# Combined CSV
COMBINED_CSV="$OUT_DIR/OVERLAP_all.csv"

echo "Cluster,TotalFixels_Cluster,Tract,TotalFixels_Tract,Sig_threshold,tract_cluster_Overlap_Fixels,tract_cluster_overlap_Percent" > $COMBINED_CSV

3dclust -NN3 -1Dformat -savemask "$STATS_DIR/clustered_mask_FWE_05.nii.gz" "$STATS_DIR/sigmask_FWE_05_bin_voxel.nii">cluster_stats_FWE_05.1D -force
3dclust -NN3 -1Dformat -savemask "$STATS_DIR/clustered_mask_unc_001.nii.gz" "$STATS_DIR/sigmask_unc_001_bin_voxel.nii">cluster_stats_unc_001.1D -force

# -----------------------------
# Loop over tracts
# -----------------------------
for tract_mask in "$TRACT_DIR"/*_fixel_mask.mif; do

    tract_name=$(basename "$tract_mask" _fixel_mask.mif)
    echo "Processing tract: $tract_name"

    OUTFILE="$OUT_DIR/OVERLAP_${tract_name}.csv"

    echo "Cluster,TotalFixels_Cluster,Tract,TotalFixels_Tract,Sig_threshold,tract_cluster_Overlap_Fixels,tract_cluster_overlap_Percent" > $OUTFILE

    # -----------------------------
    # Thresholds are converted to binary
    # -----------------------------
    mrcalc "$STATS_DIR/sigmask_FWE_05.mif" 0 -gt "$STATS_DIR/sigmask_FWE_05_bin.mif" -force
    mrcalc "$STATS_DIR/sigmask_unc_001.mif" 0 -gt "$STATS_DIR/sigmask_unc_001_bin.mif" -force
    
    # -----------------------------
    # Total fixels in tract
    # -----------------------------

    total_fixels_tract=$(mrstats "$TRACT_DIR/${tract_name}_fixel_mask.mif" -mask "$TRACT_DIR/${tract_name}_fixel_mask.mif" -output count)
    # mrcalc "$CROPPED_TRACT_DIR/${tract_name}_fixel_mask/NF101_1.mif" 0 -gt "$CROPPED_TRACT_DIR/tract_masks/${tract_name}_mask.mif"

    # whole brain signficant fixels count
      
    total_fixels_wholebrain_FWE_05=$(mrstats "$STATS_DIR/sigmask_FWE_05_bin.mif" -mask "$STATS_DIR/sigmask_FWE_05_bin.mif" -output count) 
    total_fixels_wholebrain_unc_001=$(mrstats "$STATS_DIR/sigmask_unc_001_bin.mif" -mask "$STATS_DIR/sigmask_unc_001_bin.mif" -output count)
    
    # Get number of clusters
    
    n_clusters_FWE_05=$(3dBrickStat -max "$STATS_DIR/clustered_mask_FWE_05.nii.gz")
    n_clusters_unc_001=$(3dBrickStat -max "$STATS_DIR/clustered_mask_unc_001.nii.gz")

  # Step 3: Loop through clusters
    for i in $(seq 1 $n_clusters_FWE_05); do 
	
	3dcalc -a "$STATS_DIR/clustered_mask_FWE_05.nii.gz" -expr "equals(a,$i)" -prefix "$STATS_DIR/FWE_05_cluster_${i}.nii.gz"
	fslmaths "$STATS_DIR/FWE_05_cluster_${i}.nii.gz" -bin "$STATS_DIR/FWE_05_cluster_${i}_bin.nii.gz"
        voxel2fixel "$STATS_DIR/FWE_05_cluster_${i}_bin.nii.gz" "$FIXEL_DIR" "$STATS_DIR/FWE_05_cluster_${i}" "FWE_05_cluster_${i}.mif"
	
        # Per cluster signficant fixels count
	
	# assigning values
	total_fixels_FWE_cluster[$i]=$(mrstats "$STATS_DIR/FWE_05_cluster_${i}/FWE_05_cluster_${i}.mif" -mask "$STATS_DIR/FWE_05_cluster_${i}/FWE_05_cluster_${i}.mif" -output count) 
        
        # force binarize the masks for cluster and tract prior to overlap
	mrcalc "$TRACT_DIR/${tract_name}_fixel_mask.mif" 0 -gt "$TRACT_DIR/${tract_name}_fixel_mask_bin.mif"
	mrcalc "$STATS_DIR/FWE_05_cluster_${i}/FWE_05_cluster_${i}.mif" 0 -gt "$STATS_DIR/FWE_05_cluster_${i}/FWE_05_cluster_bin_${i}.mif"

        # for each cluster, generate the overlaps
        mrcalc "$STATS_DIR/FWE_05_cluster_${i}/FWE_05_cluster_bin_${i}.mif" "$TRACT_DIR/${tract_name}_fixel_mask_bin.mif" -and "$STATS_DIR/tracts/${tract_name}_fixel_mask/FWE_05_tract_cluster_${i}_overlap.mif" -force
        tract_overlap_FWE_cluster[$i]=$(mrstats "$STATS_DIR/tracts/${tract_name}_fixel_mask/FWE_05_tract_cluster_${i}_overlap.mif" -mask "$STATS_DIR/tracts/${tract_name}_fixel_mask/FWE_05_tract_cluster_${i}_overlap.mif" -output count)

 	if [[ -z "${total_fixels_FWE_cluster[$i]}" || "${total_fixels_FWE_cluster[$i]}" -eq 0 ]]; then
        percent_FWE_cluster[$i]="NA"
        else
   	percent_FWE_cluster[$i]=$(echo "scale=4; ${tract_overlap_FWE_cluster[$i]} / ${total_fixels_FWE_cluster[$i]} * 100" | bc)
        fi

        # Write cluster info
        echo "$i,${total_fixels_FWE_cluster[$i]},$tract_name,$total_fixels_tract,FWE_05,${tract_overlap_FWE_cluster[$i]},${percent_FWE_cluster[$i]}" >> $OUTFILE
        echo "$i,${total_fixels_FWE_cluster[$i]},$tract_name,$total_fixels_tract,FWE_05,${tract_overlap_FWE_cluster[$i]},${percent_FWE_cluster[$i]}" >> $COMBINED_CSV

    
    done

    for i in $(seq 1 $n_clusters_unc_001); do 
	
        3dcalc -a "$STATS_DIR/clustered_mask_unc_001.nii.gz" -expr "equals(a,$i)" -prefix "$STATS_DIR/unc_001_cluster_${i}.nii.gz"
	fslmaths "$STATS_DIR/unc_001_cluster_${i}.nii.gz" -bin "$STATS_DIR/unc_001_cluster_${i}_bin.nii.gz"
        voxel2fixel "$STATS_DIR/unc_001_cluster_${i}_bin.nii.gz" "$FIXEL_DIR" "$STATS_DIR/unc_001_cluster_${i}" "unc_001_cluster_${i}.mif"

	 # Per cluster signficant fixels count
	total_fixels_unc_cluster[$i]=$(mrstats "$STATS_DIR/unc_001_cluster_${i}/unc_001_cluster_${i}.mif" -mask "$STATS_DIR/unc_001_cluster_${i}/unc_001_cluster_${i}.mif" -output count) 
	
	# force binarize the masks for cluster and tract prior to overlap
	#	mrcalc "$TRACT_DIR/${tract_name}_fixel_mask.mif" 0 -gt "$TRACT_DIR/${tract_name}_fixel_mask_bin.mif"
	mrcalc "$STATS_DIR/unc_001_cluster_${i}/unc_001_cluster_${i}.mif" 0 -gt "$STATS_DIR/unc_001_cluster_${i}/unc_001_cluster_bin_${i}.mif"
        

	# for each cluster, generate the overlaps
        mrcalc "$STATS_DIR/unc_001_cluster_${i}/unc_001_cluster_bin_${i}.mif" "$TRACT_DIR/${tract_name}_fixel_mask_bin.mif" -and "$STATS_DIR/tracts/${tract_name}_fixel_mask/unc_001_tract_cluster_${i}_overlap.mif" -force
        tract_overlap_unc_cluster[$i]=$(mrstats "$STATS_DIR/tracts/${tract_name}_fixel_mask/unc_001_tract_cluster_${i}_overlap.mif" -mask "$STATS_DIR/tracts/${tract_name}_fixel_mask/unc_001_tract_cluster_${i}_overlap.mif" -output count)

	if [[ -z "${total_fixels_unc_cluster[$i]}" || "${total_fixels_unc_cluster[$i]} " -eq 0 ]]; then
        percent_unc_cluster[$i]="NA"
        else
   	percent_unc_cluster[$i]=$(echo "scale=4; ${tract_overlap_unc_cluster[$i]}/ ${total_fixels_unc_cluster[$i]} * 100" | bc)
        fi
 
	# Write cluster info
	echo "$i,${total_fixels_unc_cluster[$i]},$tract_name,$total_fixels_tract,unc_001,${tract_overlap_unc_cluster[$i]},${percent_unc_cluster[$i]}" >> $OUTFILE
        echo "$i,${total_fixels_unc_cluster[$i]},$tract_name,$total_fixels_tract,unc_001,${tract_overlap_unc_cluster[$i]},${percent_unc_cluster[$i]}" >> $COMBINED_CSV
    
    done

  
    # -----------------------------
    # Percent overlap
    # -----------------------------

    if [[ -z "$total_fixels_wholebrain_FWE_05" || "$total_fixels_wholebrain_FWE_05" -eq 0 ]]; then
    percent_FWE_05="NA"
    else
    percent_FWE_05=$(echo "scale=4; $tract_overlap_FWE_05 / $total_fixels_wholebrain_FWE_05 * 100" | bc)
    fi

   
    if [[ -z "$total_fixels_wholebrain_unc_001" || "$total_fixels_wholebrain_unc_001" -eq 0 ]]; then
    percent_unc_001="NA"
    else
    percent_unc_001=$(echo "scale=4; $tract_overlap_unc_001 / $total_fixels_wholebrain_unc_001 * 100" | bc)
    fi
 
    # -----------------------------
    # Write outputs
    # -----------------------------
    echo "Whole_brain,$total_fixels_wholebrain_FWE_05,$tract_name,$total_fixels_tract,FWE_05,NA,NA" >> $OUTFILE
    echo "Whole_brain,$total_fixels_wholebrain_FWE_05,$tract_name,$total_fixels_tract,FWE_05,NA,NA" >> $COMBINED_CSV
    
    echo "Whole_brain,$total_fixels_wholebrain_unc_001,$tract_name,$total_fixels_tract,unc_001,NA,NA" >> $OUTFILE
    echo "Whole_brain,$total_fixels_wholebrain_unc_001,$tract_name,$total_fixels_tract,unc_001,NA,NA" >> $COMBINED_CSV
    

done

echo "Overlap computation complete!"
echo "Results in: $OUT_DIR"


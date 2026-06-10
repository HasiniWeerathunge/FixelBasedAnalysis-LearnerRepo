#!/bin/bash
module load mrtrix
module load AFNI
module load fsl

# -----------------------------
# Paths 
# -----------------------------
TRACT_DIR="tract_based_analysis/fixel_mask_tracts_selected"
STATS_DIR="stats_log_fc_centered_InteractionGroupAge_negative"
OUT_DIR="OVERLAP_metrics/InteractionGroupAge_negative_03272026"
CROPPED_TRACT_DIR="tract_based_analysis/tract_cropped/log_fc_smooth"
FIXEL_DIR="fixel_mask/"
mkdir "$CROPPED_TRACT_DIR/tract_masks"
mkdir -p $OUT_DIR

# Combined CSV
COMBINED_CSV="$OUT_DIR/OVERLAP_all.csv"
echo "Cluster,TotalFixels_Cluster,Tract,TotalFixels_Tract,Overlap_FWE_05,Overlap_unc_001,Percent_FWE_05(cluster),Percent_unc_001(cluster),Percent_FWE_05(whole_brain_sig_Fixels),Percent_unc_001(whole_brain_sig_Fixels)" > $COMBINED_CSV

# -----------------------------
# Loop over tracts
# -----------------------------
for tract_mask in "$TRACT_DIR"/*_fixel_mask.mif; do

    tract_name=$(basename "$tract_mask" _fixel_mask.mif)
    echo "Processing tract: $tract_name"

    OUTFILE="$OUT_DIR/OVERLAP_${tract_name}.csv"
    echo "Cluster,TotalFixels_Cluster,Tract,TotalFixels_Tract,Overlap_FWE_05,Overlap_unc_001,Percent_FWE_05,Percent_unc_001" > $OUTFILE

    # -----------------------------
    # Thresholds are converted to binary
    # -----------------------------
    mrcalc "$STATS_DIR/sigmask_FWE_05.mif" 0 -gt "$STATS_DIR/sigmask_FWE_05_bin.mif" -force
    mrcalc "$STATS_DIR/sigmask_unc_001.mif" 0 -gt "$STATS_DIR/sigmask_unc_001_bin.mif" -force
    
    # -----------------------------
    # Total fixels in tract
    # -----------------------------

    total_fixels_tract=$(mrstats "$CROPPED_TRACT_DIR/${tract_name}_fixel_mask/NF101_1.mif" -output count)
    # mrcalc "$CROPPED_TRACT_DIR/${tract_name}_fixel_mask/NF101_1.mif" 0 -gt "$CROPPED_TRACT_DIR/tract_masks/${tract_name}_mask.mif"

    # whole brain signficant fixels count
      
    total_fixels_wholebrain_FWE_05=$(mrstats "$STATS_DIR/sigmask_FWE_05_bin.mif" -mask "$STATS_DIR/sigmask_FWE_05_bin.mif" -output count) 
    total_fixels_wholebrain_unc_001=$(mrstats "$STATS_DIR/sigmask_unc_001_bin.mif" -mask "$STATS_DIR/sigmask_unc_001_bin.mif" -output count)
    
    # -----------------------------
    # Compute overlaps 
    # -----------------------------


    # convert significant fixels to a voxel image

    #fixel2voxel "$STATS_DIR/sigmask_FWE_05_bin.mif" mean "$STATS_DIR/sigmask_FWE_05_bin_voxel.mif" 
    #fixel2voxel "$STATS_DIR/sigmask_unc_001_bin.mif" mean "$STATS_DIR/sigmask_unc_001_bin_voxel.mif"
  
    #mrconvert "$STATS_DIR/sigmask_FWE_05_bin_voxel.mif" "$STATS_DIR/sigmask_FWE_05_bin_voxel.nii"
    #mrconvert "$STATS_DIR/sigmask_unc_001_bin_voxel.mif" "$STATS_DIR/sigmask_unc_001_bin_voxel.nii"
  
    # seperate out clusters and consider them seperately in a nested loop
    # Step 1: Create cluster index + peaks
    #cluster -i "$STATS_DIR/sigmask_FWE_05_bin_voxel.nii" -t 0.5 --oindex="$STATS_DIR/FWE_05_cluster_index.nii" --olmax="$STATS_DIR/FWE_05_peaks.txt"
    #cluster -i "$STATS_DIR/sigmask_unc_001_bin_voxel.nii" -t 0.5 --oindex="$STATS_DIR/unc_001_cluster_index.nii" --olmax="$STATS_DIR/unc_001_peaks.txt"

    
  
    # Step 2: Get number of clusters
    #n_clusters_FWE_05=$(fslstats "$STATS_DIR/FWE_05_cluster_index.nii" -R | awk '{print int($2)}')
    #n_clusters_unc_001=$(fslstats "$STATS_DIR/unc_001_cluster_index.nii" -R | awk '{print int($2)}')

    n_clusters_FWE_05=$(3dBrickStat -max "$STATS_DIR/clustered_mask_FWE_05.nii.gz")
    n_clusters_unc_001=$(3dBrickStat -max "$STATS_DIR/clustered_mask_unc_001.nii.gz")


    #echo "Number of clusters: $n_clusters"

    # Step 3: Loop through clusters
    for i in $(seq 1 $n_clusters_FWE_05); do 
	#fslmaths "$STATS_DIR/FWE_05_cluster_index.nii" -thr $i -uthr $i -bin "$STATS_DIR/FWE_05_cluster_${i}.nii.gz" 
	fslmaths "$STATS_DIR/FWE_05_cluster_${i}.nii.gz" -bin "$STATS_DIR/FWE_05_cluster_${i}_bin.nii.gz"
        voxel2fixel "$STATS_DIR/FWE_05_cluster_${i}_bin.nii.gz" "$FIXEL_DIR" "$STATS_DIR/FWE_05_cluster_${i}" "FWE_05_cluster_${i}.mif"
	#mrcalc "$STATS_DIR/sigmask_FWE_05.mif" "$STATS_DIR/FWE_05_cluster_${i}/FWE_05_cluster_${i}.mif" -and "$STATS_DIR/FWE_05_cluster_${i}/FWE_05_cluster_${i}_overlap.mif" 
        
        # Per cluster signficant fixels count
	total_fixels_cluter_${i}_FWE_05=$(mrstats "$STATS_DIR/FWE_05_cluster_${i}/FWE_05_cluster_${i}.mif" -mask "$STATS_DIR/FWE_05_cluster_${i}/FWE_05_cluster_${i}.mif" -output count) 
   
        # for each cluster, generate the overlaps
        mrcalc "$STATS_DIR/FWE_05_cluster_${i}/FWE_05_cluster_${i}.mif" "$TRACT_DIR/${tract_name}_fixel_mask.mif" -and "$STATS_DIR/tracts/${tract_name}_fixel_mask/FWE_05_tract_cluster_${i}_overlap.mif" 
        tract_cluster_${i}_overlap_FWE_05=$(mrstats "$STATS_DIR/tracts/${tract_name}_fixel_mask/FWE_05_tract_cluster_${i}_overlap.mif" -mask "$STATS_DIR/tracts/${tract_name}_fixel_mask/FWE_05_tract_cluster_${i}_overlap.mif" -output count)

 	if [[ -z "$total_fixels_cluster_${i}_FWE_05" || "$total_fixels_cluster_${i}_FWE_05" -eq 0 ]]; then
        percent__cluster_${i}_FWE_05="NA"
        else
   	percent__cluster_${i}_FWE_05=$(echo "scale=4; $tract_overlap_FWE_05 / $total_fixels_cluter_${i}_FWE_05 * 100" | bc)
        fi
    
    done

    for i in $(seq 1 $n_clusters_unc_001); do 
	
        fslmaths "$STATS_DIR/unc_001_cluster_${i}.nii.gz" -bin "$STATS_DIR/unc_001_cluster_${i}_bin.nii.gz"
        voxel2fixel "$STATS_DIR/unc_001_cluster_${i}_bin.nii.gz" "$FIXEL_DIR" "$STATS_DIR/unc_001_cluster_${i}" "unc_001_cluster_${i}.mif"

	 # Per cluster signficant fixels count
	total_fixels_cluter_${i}_unc_001=$(mrstats "$STATS_DIR/unc_001_cluster_${i}/unc_001_cluster_${i}.mif" -mask "$STATS_DIR/unc_001_cluster_${i}/unc_001_cluster_${i}.mif" -output count) 
	
        # for each cluster, generate the overlaps
        mrcalc "$STATS_DIR/unc_001_cluster_${i}/unc_001_cluster_${i}.mif" "$TRACT_DIR/${tract_name}_fixel_mask.mif" -and "$STATS_DIR/tracts/${tract_name}_fixel_mask/unc_001_tract_cluster_${i}_overlap.mif" 
        tract_cluster_${i}_overlap_unc_001=$(mrstats "$STATS_DIR/tracts/${tract_name}_fixel_mask/unc_001_tract_cluster_${i}_overlap.mif" -mask "$STATS_DIR/tracts/${tract_name}_fixel_mask/unc_001_tract_cluster_${i}_overlap.mif" -output count)

	if [[ -z "$total_fixels_cluster_${i}_unc_001" || "$total_fixels_cluster_${i}_unc_001" -eq 0 ]]; then
        percent__cluster_${i}_unc_001="NA"
        else
   	percent__cluster_${i}_unc_001=$(echo "scale=4; $tract_overlap_unc_001 / $total_fixels_cluter_${i}_unc_001 * 100" | bc)
        fi
    
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

   

   #percent_FWE_05=$(echo "scale=4; $overlap_FWE_05 / $total_fixels_wholebrain_FWE_05 * 100" | bc)
   #percent_FWE_005=$(echo "scale=4; $overlap_FWE_005 / $total_fixels_wholebrain_FWE_005 * 100" | bc)
   #percent_unc_001=$(echo "scale=4; $overlap_unc_001 / $total_fixels_wholebrain_unc_001 * 100" | bc)
   #percent_unc_0025=$(echo "scale=4; $overlap_unc_0025 / $total_fixels_wholebrain_unc_0025 * 100" | bc)
   #percent_unc_005=$(echo "scale=4; $overlap_unc_005 / $total_fixels_wholebrain_unc_005 * 100" | bc)

    # -----------------------------
    # Write outputs
    # -----------------------------
 #   echo "$tract_name,$total_fixels_tract,$overlap_FWE_05,$overlap_FWE_005,$overlap_unc_001,$overlap_unc_0025,$overlap_unc_005,$percent_FWE_05,$percent_FWE_005,$percent_unc_001,$percent_unc_0025,$percent_unc_005" >> $OUTFILE

 #   echo "$tract_name,$total_fixels_tract,$overlap_FWE_05,$overlap_FWE_005,$overlap_unc_001,$overlap_unc_0025,$overlap_unc_005,$percent_FWE_05,$percent_FWE_005,$percent_unc_001,$percent_unc_0025,$percent_unc_005" >> $COMBINED_CSV

echo "$tract_name,$total_fixels_tract,$tract_overlap_FWE_05,$tract_overlap_unc_001,$percent_FWE_05,$percent_unc_001" >> $OUTFILE

    echo "$tract_name,$total_fixels_tract,$tract_overlap_FWE_05,$tract_overlap_unc_001,$percent_FWE_05,$percent_unc_001" >> $COMBINED_CSV



done

echo "Overlap computation complete!"
echo "Results in: $OUT_DIR"


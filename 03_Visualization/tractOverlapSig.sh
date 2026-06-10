#!/bin/bash
module load mrtrix

# -----------------------------
# Paths (same structure as yours)
# -----------------------------
TRACT_DIR="tract_based_analysis/fixel_mask_tracts_selected"
STATS_DIR="stats_log_fc_centered_Group_negative"
OUT_DIR="OVERLAP_metrics/Group_negative"
CROPPED_TRACT_DIR="tract_based_analysis/tract_cropped/log_fc_smooth"
mkdir "$CROPPED_TRACT_DIR/tract_masks"
mkdir -p $OUT_DIR

# Combined CSV
COMBINED_CSV="$OUT_DIR/OVERLAP_all.csv"
echo "Tract,TotalFixels,Overlap_FWE_05,Overlap_FWE_005,Overlap_unc_001,Overlap_unc_0025,Overlap_unc_005,Percent_FWE_05,Percent_FWE_005,Percent_unc_001,Percent_unc_0025,Percent_unc_005" > $COMBINED_CSV

# -----------------------------
# Loop over tracts
# -----------------------------
for tract_mask in "$TRACT_DIR"/*_fixel_mask.mif; do

    tract_name=$(basename "$tract_mask" _fixel_mask.mif)
    echo "Processing tract: $tract_name"

    OUTFILE="$OUT_DIR/OVERLAP_${tract_name}.csv"
    echo "Tract,TotalFixels,Overlap_FWE_05,Overlap_FWE_005,Overlap_unc_001,Overlap_unc_0025,Overlap_unc_005,Percent_FWE_05,Percent_FWE_005,Percent_unc_001,Percent_unc_0025,Percent_unc_005" > $OUTFILE

   # -----------------------------
   # Thresholds are converted to binary
   # -----------------------------
   mrcalc "$STATS_DIR/sigmask_FWE_05.mif" 0 -gt "$STATS_DIR/sigmask_FWE_05_bin.mif" -force
   mrcalc "$STATS_DIR/sigmask_FWE_005.mif" 0 -gt "$STATS_DIR/sigmask_FWE_005_bin.mif" -force
   mrcalc "$STATS_DIR/sigmask_unc_001.mif" 0 -gt "$STATS_DIR/sigmask_unc_001_bin.mif" -force
   mrcalc "$STATS_DIR/sigmask_unc_0025.mif" 0 -gt "$STATS_DIR/sigmask_unc_0025_bin.mif" -force
   mrcalc "$STATS_DIR/sigmask_unc_005.mif" 0 -gt "$STATS_DIR/sigmask_unc_005_bin.mif" -force

    
    # -----------------------------
    # Total fixels in tract
    # -----------------------------

    total_fixels_tract=$(mrstats "$CROPPED_TRACT_DIR/${tract_name}_fixel_mask/NF101_1.mif" -output count)
   # mrcalc "$CROPPED_TRACT_DIR/${tract_name}_fixel_mask/NF101_1.mif" 0 -gt "$CROPPED_TRACT_DIR/tract_masks/${tract_name}_mask.mif"

 

    # whole brain signficant fixels count
      
    total_fixels_wholebrain_FWE_05=$(mrstats "$STATS_DIR/sigmask_FWE_05_bin.mif" -mask "$STATS_DIR/sigmask_FWE_05_bin.mif" -output count) 
    total_fixels_wholebrain_FWE_005=$(mrstats "$STATS_DIR/sigmask_FWE_005_bin.mif" -mask "$STATS_DIR/sigmask_FWE_005_bin.mif" -output count)
    total_fixels_wholebrain_unc_001=$(mrstats "$STATS_DIR/sigmask_unc_001_bin.mif" -mask "$STATS_DIR/sigmask_unc_001_bin.mif" -output count)
    total_fixels_wholebrain_unc_0025=$(mrstats "$STATS_DIR/sigmask_unc_0025_bin.mif" -mask "$STATS_DIR/sigmask_unc_0025_bin.mif" -output count)
    total_fixels_wholebrain_unc_005=$(mrstats "$STATS_DIR/sigmask_unc_005_bin.mif" -mask "$STATS_DIR/sigmask_unc_005_bin.mif" -output count)
    
    # -----------------------------
    # Compute overlaps 
    # -----------------------------

    # whole brain signficant and tract whole

   #"$CROPPSED_TRACT_DIR/tract_masks/${tract_name}_mask.mif" 
   
    mrcalc "$STATS_DIR/sigmask_FWE_05.mif" "$TRACT_DIR/${tract_name}_fixel_mask.mif" -and "$STATS_DIR/tracts/${tract_name}_fixel_mask/tract_overlap_FWE_05.mif" -force
    mrcalc "$STATS_DIR/sigmask_FWE_005.mif" "$TRACT_DIR/${tract_name}_fixel_mask.mif" -and "$STATS_DIR/tracts/${tract_name}_fixel_mask/tract_overlap_FWE_005.mif" -force
    mrcalc "$STATS_DIR/sigmask_unc_001.mif" "$TRACT_DIR/${tract_name}_fixel_mask.mif" -and "$STATS_DIR/tracts/${tract_name}_fixel_mask/tract_overlap_unc_001.mif" -force
    mrcalc "$STATS_DIR/sigmask_unc_0025.mif" "$TRACT_DIR/${tract_name}_fixel_mask.mif" -and "$STATS_DIR/tracts/${tract_name}_fixel_mask/tract_overlap_unc_0025.mif" -force
    mrcalc "$STATS_DIR/sigmask_unc_005.mif" "$TRACT_DIR/${tract_name}_fixel_mask.mif" -and "$STATS_DIR/tracts/${tract_name}_fixel_mask/tract_overlap_unc_005.mif" -force
   
    tract_overlap_FWE_05=$(mrstats "$STATS_DIR/tracts/${tract_name}_fixel_mask/tract_overlap_FWE_05.mif" -mask "$STATS_DIR/tracts/${tract_name}_fixel_mask/tract_overlap_FWE_05.mif" -output count)
    tract_overlap_FWE_005=$(mrstats "$STATS_DIR/tracts/${tract_name}_fixel_mask/tract_overlap_FWE_005.mif" -mask "$STATS_DIR/tracts/${tract_name}_fixel_mask/tract_overlap_FWE_005.mif" -output count)
    tract_overlap_unc_001=$(mrstats "$STATS_DIR/tracts/${tract_name}_fixel_mask/tract_overlap_unc_001.mif" -mask "$STATS_DIR/tracts/${tract_name}_fixel_mask/tract_overlap_unc_001.mif" -output count)
    tract_overlap_unc_0025=$(mrstats "$STATS_DIR/tracts/${tract_name}_fixel_mask/tract_overlap_unc_0025.mif" -mask "$STATS_DIR/tracts/${tract_name}_fixel_mask/tract_overlap_unc_0025.mif" -output count)
    tract_overlap_unc_005=$(mrstats "$STATS_DIR/tracts/${tract_name}_fixel_mask/tract_overlap_unc_005.mif" -mask "$STATS_DIR/tracts/${tract_name}_fixel_mask/tract_overlap_unc_005.mif" -output count)

    # whole brain significant and tract signficant

    mrcalc "$STATS_DIR/sigmask_FWE_05.mif" "$STATS_DIR/tracts/${tract_name}_fixel_mask/sigmask_FWE_05.mif" -and "$STATS_DIR/tracts/${tract_name}_fixel_mask/overlap_FWE_05.mif" -force
    mrcalc "$STATS_DIR/sigmask_FWE_005.mif" "$STATS_DIR/tracts/${tract_name}_fixel_mask/sigmask_FWE_005.mif" -and "$STATS_DIR/tracts/${tract_name}_fixel_mask/overlap_FWE_005.mif" -force
    mrcalc "$STATS_DIR/sigmask_unc_001.mif" "$STATS_DIR/tracts/${tract_name}_fixel_mask/sigmask_unc_001.mif" -and "$STATS_DIR/tracts/${tract_name}_fixel_mask/overlap_unc_001.mif" -force
    mrcalc "$STATS_DIR/sigmask_unc_0025.mif" "$STATS_DIR/tracts/${tract_name}_fixel_mask/sigmask_unc_0025.mif" -and "$STATS_DIR/tracts/${tract_name}_fixel_mask/overlap_unc_0025.mif" -force
    mrcalc "$STATS_DIR/sigmask_unc_005.mif" "$STATS_DIR/tracts/${tract_name}_fixel_mask/sigmask_unc_005.mif" -and "$STATS_DIR/tracts/${tract_name}_fixel_mask/overlap_unc_005.mif" -force
   
    overlap_FWE_05=$(mrstats "$STATS_DIR/tracts/${tract_name}_fixel_mask/overlap_FWE_05.mif" -mask "$STATS_DIR/tracts/${tract_name}_fixel_mask/overlap_FWE_05.mif" -output count)
    overlap_FWE_005=$(mrstats "$STATS_DIR/tracts/${tract_name}_fixel_mask/overlap_FWE_005.mif" -mask "$STATS_DIR/tracts/${tract_name}_fixel_mask/overlap_FWE_005.mif" -output count)
    overlap_unc_001=$(mrstats "$STATS_DIR/tracts/${tract_name}_fixel_mask/overlap_unc_001.mif" -mask "$STATS_DIR/tracts/${tract_name}_fixel_mask/overlap_unc_001.mif" -output count)
    overlap_unc_0025=$(mrstats "$STATS_DIR/tracts/${tract_name}_fixel_mask/overlap_unc_0025.mif" -mask "$STATS_DIR/tracts/${tract_name}_fixel_mask/overlap_unc_0025.mif" -output count)
    overlap_unc_005=$(mrstats "$STATS_DIR/tracts/${tract_name}_fixel_mask/overlap_unc_005.mif" -mask "$STATS_DIR/tracts/${tract_name}_fixel_mask/overlap_unc_005.mif" -output count)

    # -----------------------------
    # Percent overlap
    # -----------------------------

    if [[ -z "$total_fixels_wholebrain_FWE_05" || "$total_fixels_wholebrain_FWE_05" -eq 0 ]]; then
    percent_FWE_05="NA"
    else
    percent_FWE_05=$(echo "scale=4; $tract_overlap_FWE_05 / $total_fixels_wholebrain_FWE_05 * 100" | bc)
    fi

    if [[ -z "$total_fixels_wholebrain_FWE_005" || "$total_fixels_wholebrain_FWE_005" -eq 0 ]]; then
    percent_FWE_005="NA"
    else
    percent_FWE_005=$(echo "scale=4; $tract_overlap_FWE_005 / $total_fixels_wholebrain_FWE_005 * 100" | bc)
    fi

    if [[ -z "$total_fixels_wholebrain_unc_001" || "$total_fixels_wholebrain_unc_001" -eq 0 ]]; then
    percent_unc_001="NA"
    else
    percent_unc_001=$(echo "scale=4; $tract_overlap_unc_001 / $total_fixels_wholebrain_unc_001 * 100" | bc)
    fi

    if [[ -z "$total_fixels_wholebrain_unc_0025" || "$total_fixels_wholebrain_unc_0025" -eq 0 ]]; then
    percent_unc_0025="NA"
    else
    percent_unc_0025=$(echo "scale=4; $tract_overlap_unc_0025 / $total_fixels_wholebrain_unc_0025 * 100" | bc)
    fi

    if [[ -z "$total_fixels_wholebrain_unc_005" || "$total_fixels_wholebrain_unc_005" -eq 0 ]]; then
    percent_unc_005="NA"
    else
    percent_unc_005=$(echo "scale=4; $tract_overlap_unc_005 / $total_fixels_wholebrain_unc_005 * 100" | bc)
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

echo "$tract_name,$total_fixels_tract,$tract_overlap_FWE_05,$tract_overlap_FWE_005,$tract_overlap_unc_001,$tract_overlap_unc_0025,$tract_overlap_unc_005,$percent_FWE_05,$percent_FWE_005,$percent_unc_001,$percent_unc_0025,$percent_unc_005" >> $OUTFILE

    echo "$tract_name,$total_fixels_tract,$tract_overlap_FWE_05,$tract_overlap_FWE_005,$tract_overlap_unc_001,$tract_overlap_unc_0025,$tract_overlap_unc_005,$percent_FWE_05,$percent_FWE_005,$percent_unc_001,$percent_unc_0025,$percent_unc_005" >> $COMBINED_CSV



done

echo "Overlap computation complete!"
echo "Results in: $OUT_DIR"


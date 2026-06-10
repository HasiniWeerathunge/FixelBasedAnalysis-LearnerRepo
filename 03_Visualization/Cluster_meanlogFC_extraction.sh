#!/bin/bash

module load mrtrix

# -----------------------------
# PATHS (EDIT THESE)
# -----------------------------
SUBJECT_DIR="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template_cohort1and2_all/log_fc_smooth/"   # each subject has log_fc.mif
STATS_DIR="stats_log_fc_centered_InteractionGroupAge_negative"
OUT_DIR="OVERLAP_metrics/InteractionGroupAge_negative_03312026"

mkdir -p "$OUT_DIR"

# -----------------------------
# OUTPUT CSV
# -----------------------------
OUT_CSV="$OUT_DIR/cluster_mean_logFC_per_subject.csv"

echo "Subject,Cluster,Threshold,Mean_logFC" > "$OUT_CSV"

# -----------------------------
# GET CLUSTER COUNTS
# -----------------------------
#n_clusters_FWE_05=$(ls -d $STATS_DIR/FWE_05_cluster_* 2>/dev/null | wc -l)
n_clusters_unc_001=$(ls -d $STATS_DIR/unc_001_cluster_* 2>/dev/null | wc -l)

#echo "FWE clusters: $n_clusters_FWE_05"
echo "Uncorrected clusters: $n_clusters_unc_001"

# -----------------------------
# SUBJECT LOOP
# -----------------------------
for logfc_file in "$SUBJECT_DIR"/*_1.mif; do


    subj=$(basename "$logfc_file"_1.mif)   # Extract subject ID (remove path + suffix)
   
    echo "Processing subject: $subj"

  
    # -----------------------------
    # UNCORRECTED p <.001 CLUSTERS
    # -----------------------------
    for i in $(seq 1 $n_clusters_unc_001); do

        cluster_mask="$STATS_DIR/unc_001_cluster_${i}/unc_001_cluster_${i}.mif"

        if [[ ! -f "$cluster_mask" ]]; then
            echo "Missing cluster mask: $cluster_mask"
            continue
        fi

        # Ensure binary mask
        bin_mask="$STATS_DIR/unc_001_cluster_${i}/unc_001_cluster_${i}_bin.mif"
        mrcalc "$cluster_mask" 0 -gt "$bin_mask" -force

        mean_logfc=$(mrstats "$logfc_file" \
            -mask "$bin_mask" \
            -output mean)

        if [[ -z "$mean_logfc" ]]; then
            mean_logfc="NA"
        fi

        echo "$subj,$i,unc_001,$mean_logfc" >> "$OUT_CSV"
    done

done

echo "----------------------------------"
echo "Extraction complete!"
echo "Output: $OUT_CSV"
echo "----------------------------------"


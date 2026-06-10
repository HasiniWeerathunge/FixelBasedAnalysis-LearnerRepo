#!/bin/bash
# =============================================================================
# master_visualization_pipeline.sh
#
# Orchestrates the post-stats Visualization/extraction scripts in this folder.
# See PIPELINE_README.md for a full description of every step.
#
# IMPORTANT:
#   - Every script in this folder is hard-coded to a single statistical
#     contrast via a STATS_DIR (and OUT_DIR / TRACT_DIR / FIXEL_DIR / etc.)
#     variable near the top of the file. Before running this master script,
#     open EACH step's script and set these to the contrast directory you
#     want to process (e.g. "stats_log_fc_centered_Group_negative",
#     "stats_log_fc_centered_InteractionGroupAge_negative", ...).
#   - This script does NOT edit those variables for you - it just runs the
#     scripts in a sensible order, pausing before each one.
#   - Step 6 (tract overlap) has three versions; only the latest
#     (03302026_clustersVersion) is run by default. Set
#     RUN_OLD_OVERLAP_VERSIONS=yes to also be prompted for the two earlier
#     versions.
#
# Usage:
#   ./master_visualization_pipeline.sh           # walk through all steps
#   ./master_visualization_pipeline.sh 4         # start prompting from step 4
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

START_STEP="${1:-1}"
COUNTER=0

run_step () {
    local label="$1"
    local description="$2"
    local script="$3"

    COUNTER=$((COUNTER + 1))
    if (( COUNTER < START_STEP )); then
        echo "Skipping step $label (before requested start step $START_STEP): $description"
        return 0
    fi

    echo
    echo "============================================================"
    echo "Step $label: $description"
    echo "  -> $script"
    echo "============================================================"
    read -p "Run this step now? [y/N/q] " choice
    case "$choice" in
        y|Y)
            bash "$SCRIPT_DIR/$script"
            ;;
        q|Q)
            echo "Stopping pipeline at step $label."
            exit 0
            ;;
        *)
            echo "Skipping step $label."
            ;;
    esac
}

# -----------------------------------------------------------------------
# Step 1: Threshold stats maps to significance masks + generate .tsf
#   tracks for visualisation in mrview.
#   Edit STATS_DIR (only one uncommented) before running.
# -----------------------------------------------------------------------
run_step "1" "Significance masks + track visualisation files (tsf)" \
    "tsfscript.sh"

# -----------------------------------------------------------------------
# Step 2: Spatially cluster significant fixels (AFNI 3dclust).
#   Edit STATS_DIR before running. Requires `module load mrtrix afni`.
#   NOTE: see PIPELINE_README.md - some referenced voxel masks must be
#   generated manually before the MNI-cluster block will run.
# -----------------------------------------------------------------------
run_step "2" "Spatial clustering of significant fixels" \
    "ClusteringSigFixels.sh"

# -----------------------------------------------------------------------
# Step 3: Per-subject mean logFC within each significant cluster -> CSV
#   Edit SUBJECT_DIR, STATS_DIR, OUT_DIR before running. Requires step 2
#   to have produced unc_001_cluster_<i> fixel masks.
# -----------------------------------------------------------------------
run_step "3" "Per-cluster mean logFC extraction" \
    "Cluster_meanlogFC_extraction.sh"

# -----------------------------------------------------------------------
# Step 4: Per-tract significant-fixel mean logFC -> CSV
#   Edit TRACT_DIR, STATS_DIR, OUT_DIR before running.
# -----------------------------------------------------------------------
run_step "4" "Per-tract mean logFC extraction" \
    "mean_log_fc_generation.sh"

# -----------------------------------------------------------------------
# Step 5: Whole-brain significant-fixel mean logFC -> CSV
#   Edit STATS_DIR, OUT_DIR before running.
# -----------------------------------------------------------------------
run_step "5" "Whole-brain mean logFC extraction" \
    "mean_log_fc_generation_wholebrain.sh"

# -----------------------------------------------------------------------
# Step 6: Tract / significant-fixel overlap (latest version)
#   Edit TRACT_DIR, STATS_DIR, OUT_DIR, CROPPED_TRACT_DIR, FIXEL_DIR
#   before running. Requires `module load mrtrix AFNI fsl`.
# -----------------------------------------------------------------------
run_step "6" "Tract/cluster overlap with significant fixels (latest)" \
    "tractOverlapSig_03302026_clustersVersion.sh"

if [[ "${RUN_OLD_OVERLAP_VERSIONS:-no}" == "yes" ]]; then
    run_step "6b" "Tract overlap (original version)" \
        "tractOverlapSig.sh"
    run_step "6c" "Tract overlap (03232026 clusters version)" \
        "tractOverlapSig_03232026_clustersVersion.sh"
fi

echo
echo "============================================================"
echo "Visualization pipeline run complete (or stopped at requested step)."
echo "Outputs (significance masks, .tsf tracks, cluster masks, and CSVs)"
echo "feed into Figure_generation/ for plotting."
echo "============================================================"

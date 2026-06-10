#!/bin/bash
# =============================================================================
# master_pipeline.sh
#
# Orchestrates the post-stats Visualization (Part 1, bash/MRtrix/AFNI) and
# Figure generation (Part 2, R/ggplot2) scripts in this folder.
# See PIPELINE_README.md for a full description of every step.
#
# IMPORTANT:
#   - Every Part 1 script is hard-coded to a single statistical contrast via
#     a STATS_DIR (and OUT_DIR / TRACT_DIR / FIXEL_DIR / etc.) variable near
#     the top of the file. Before running this master script, open EACH
#     step's script and set these to the contrast directory you want to
#     process (e.g. "stats_log_fc_centered_Group_negative",
#     "stats_log_fc_centered_InteractionGroupAge_negative", ...).
#   - Every Part 2 (R) script hard-codes setwd() to the SIG_mean_logFC/
#     directory produced by Part 1. Update these paths if running on a
#     different machine/mount.
#   - This script does NOT edit those variables for you - it just runs the
#     scripts in a sensible order, pausing before each one.
#   - Step 6 (tract overlap) has three versions; only the latest
#     (03302026_clustersVersion) is run by default. Set
#     RUN_OLD_OVERLAP_VERSIONS=yes to also be prompted for the two earlier
#     versions.
#   - Part 2 requires R with: dplyr, tidyr, ggplot2, ggdist, broom, lme4,
#     lmerTest. Most ggsave() calls in the R scripts are commented out -
#     uncomment/add them where you want PNG/PDF output.
#
# Usage:
#   ./master_pipeline.sh           # walk through all steps, prompting
#   ./master_pipeline.sh 4         # start prompting from step 4 onwards
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

START_STEP="${1:-1}"
COUNTER=0

run_step () {
    local label="$1"
    local description="$2"
    local script="$3"
    local interpreter="${4:-bash}"

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
            "$interpreter" "$SCRIPT_DIR/$script"
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

# =============================================================================
# Part 1: Visualization (post-stats extraction)
# =============================================================================

# -----------------------------------------------------------------------
# Step 1: Significance masks + track visualisation files (tsf)
#   Edit STATS_DIR (only one uncommented) before running.
# -----------------------------------------------------------------------
run_step "1" "Significance masks + track visualisation files (tsf)" \
    "tsfscript.sh"

# -----------------------------------------------------------------------
# Step 2: Spatial clustering of significant fixels (AFNI 3dclust)
#   Edit STATS_DIR before running. Requires `module load mrtrix afni`.
#   NOTE: see PIPELINE_README.md - some referenced voxel masks must be
#   generated manually before the MNI-cluster block will run.
# -----------------------------------------------------------------------
run_step "2" "Spatial clustering of significant fixels" \
    "ClusteringSigFixels.sh"

# -----------------------------------------------------------------------
# Step 3: Per-cluster mean logFC extraction
#   Edit SUBJECT_DIR, STATS_DIR, OUT_DIR before running. Requires step 2
#   to have produced unc_001_cluster_<i> fixel masks.
# -----------------------------------------------------------------------
run_step "3" "Per-cluster mean logFC extraction" \
    "Cluster_meanlogFC_extraction.sh"

# -----------------------------------------------------------------------
# Step 4: Per-tract mean logFC extraction
#   Edit TRACT_DIR, STATS_DIR, OUT_DIR before running.
# -----------------------------------------------------------------------
run_step "4" "Per-tract mean logFC extraction" \
    "mean_log_fc_generation.sh"

# -----------------------------------------------------------------------
# Step 5: Whole-brain mean logFC extraction
#   Edit STATS_DIR, OUT_DIR before running.
# -----------------------------------------------------------------------
run_step "5" "Whole-brain mean logFC extraction" \
    "mean_log_fc_generation_wholebrain.sh"

# -----------------------------------------------------------------------
# Step 6: Tract/cluster overlap with significant fixels (latest version)
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

# =============================================================================
# Part 2: Figure generation (recommended R scripts, in order)
# =============================================================================

run_step "7" "Group bar/raincloud (Control vs Stuttering)" \
    "BarPlots_04172026_ControlStutt_residual_raincloud_siglevelsOnly.R" "Rscript"

run_step "8" "Group bar (Persistent/Recovered/Control GLM)" \
    "BarPlots_04172026_persist_GLM.R" "Rscript"

run_step "9" "Fig2 cluster scatter (Age x Group, covariate-corrected)" \
    "Clusters_Fig2_Age_Group_covariate_corrected.R" "Rscript"

run_step "10" "Fig2 cluster scatter (SSI-4, Stuttering only)" \
    "Clusters_Fig2_SSI4_Group_covariatecorrected.R" "Rscript"

run_step "11" "Fig3/4 tract bar + raincloud (style matched)" \
    "Fig3_barplots.R" "Rscript"

run_step "12" "Fig3/4 tract scatter (Age x Group, match cluster style)" \
    "Fig_2_4_Scatter_plots_AgeGroup.R" "Rscript"

run_step "13" "Fig3/4 tract scatter (SSI-4, match cluster style)" \
    "Tracts_Fig3and4_SSI_logFC_scatterPlots.R" "Rscript"

run_step "14" "Residual scatter vs SSI/SLD (interaction model)" \
    "Residual_interactionModel_ScatterPlots_forSSI_SLD_03232026_persistantRecovered_sigOnly.R" "Rscript"

run_step "15" "Mixed-effects Age x Group interaction" \
    "age_group_interaction_04212026.R" "Rscript"

echo
echo "============================================================"
echo "Pipeline run complete (or stopped at requested step)."
echo "All other *.R scripts are earlier figure iterations, kept for"
echo "reference - run individually with 'Rscript <script>.R' if needed"
echo "to reproduce older figure versions. See PIPELINE_README.md."
echo "============================================================"

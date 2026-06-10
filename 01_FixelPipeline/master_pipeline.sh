#!/bin/bash
# =============================================================================
# master_pipeline.sh
#
# Orchestrates the MercuryShellScripts fixel-based analysis (FBA) pipeline.
# See PIPELINE_README.md for a full description of every step.
#
# IMPORTANT:
#   - Each numbered script below has its own hard-coded `parent_dir` and
#     output suffixes (e.g. "_cohort2", "RC1"). Open and edit each script
#     BEFORE running this master script for a new dataset/cohort.
#   - Several steps are interactive (QA1) or require a manual decision
#     (population template subject selection, ROI coordinates, which
#     fixelcfestats blocks to run). This script pauses before every step.
#   - Steps 6, 7 (registration/connectivity/SIFT/fixelcfestats) can take
#     many hours and large amounts of memory — run on the cluster with
#     appropriate resource requests, not interactively.
#
# Usage:
#   ./master_pipeline.sh           # walk through all steps, prompting
#                                   # at each one (y = run, n = skip, q = quit)
#   ./master_pipeline.sh 4         # start prompting from step 4 onwards
#                                   # (steps before 4 are skipped automatically)
#
# Optional: set RUN_SUBGROUP_CSD=yes to also be prompted for the
# per-subgroup CSD scripts (NF/NM/SF/SM) after step 4.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

START_STEP="${1:-1}"
COUNTER=0

# -----------------------------------------------------------------------
# Helper: prints a header for the step, prompts the user (y/N/q), and runs
# the given script if confirmed. Steps before START_STEP are skipped
# automatically without prompting.
# -----------------------------------------------------------------------
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
# Step 1: Per-subject response function estimation (dwi2response dhollander)
# -----------------------------------------------------------------------
run_step "1" "Per-subject response function estimation" \
    "01_batch_fixel_script_responsefunction.sh"

# -----------------------------------------------------------------------
# Step 2: Group-average response functions (responsemean)
# -----------------------------------------------------------------------
run_step "2" "Group-average response functions" \
    "02_batch_fixel_script_responseGroupAverage.sh"

# -----------------------------------------------------------------------
# Step 3: Upsample brain masks to 1.25mm (mrgrid regrid)
#   NOTE: if dwi_upsampled.mif / dwi_mask_upsampled.mif do not exist yet,
#   uncomment the relevant lines inside this script first (mrgrid on dwi,
#   dwi2mask on the upsampled dwi).
# -----------------------------------------------------------------------
run_step "3" "Upsample brain masks (and DWI/mask if needed)" \
    "03_batch_fixel_script_resizeMask.sh"

# -----------------------------------------------------------------------
# Step 4: Single-Shell 3-Tissue CSD (FOD estimation)
#   Uses group-average response functions from step 2.
#   FIX REQUIRED: change "N = 64" to "N=64" (no spaces) before running.
#
#   If processing the four sub-cohorts separately, set
#   RUN_SUBGROUP_CSD=yes to also be prompted for the matching
#   batch_fixel_parallel_{NF,NM,SF,SM}.sh scripts below.
# -----------------------------------------------------------------------
run_step "4" "Single-Shell 3-Tissue CSD (FOD estimation)" \
    "04_batch_fixel_script_SSMT_CSD.sh"

if [[ "${RUN_SUBGROUP_CSD:-no}" == "yes" ]]; then
    run_step "4b" "CSD for subgroup NF" "batch_fixel_parallel_NF.sh"
    run_step "4c" "CSD for subgroup NM" "batch_fixel_parallel_NM.sh"
    run_step "4d" "CSD for subgroup SF" "batch_fixel_parallel_SF.sh"
    run_step "4e" "CSD for subgroup SM" "batch_fixel_parallel_SM.sh"
fi

# -----------------------------------------------------------------------
# Step 5: Joint bias-field correction & intensity normalisation (mtnormalise)
# -----------------------------------------------------------------------
run_step "5" "Bias-field correction & intensity normalisation" \
    "05_batch_fixel_script_biasTX_nonrmalize.sh"

# -----------------------------------------------------------------------
# QA1: Visual QC of upsampled brain masks (interactive, mrview)
#   Confirm every subject mask covers all brain regions needed for
#   analysis before building the population template.
# -----------------------------------------------------------------------
run_step "QA1" "Visual QC of upsampled brain masks (interactive mrview)" \
    "QA1_batch_QA1_mrview.sh"

# -----------------------------------------------------------------------
# Step 6: Build the study-specific FOD population template
#   By default this links ALL subjects' wmfod_norm.mif/masks into
#   ../template/{fod_input,mask_input}. To use a balanced subset instead
#   (e.g. top 10 subjects per group), edit and uncomment the relevant
#   for_each blocks inside this script before running.
# -----------------------------------------------------------------------
run_step "6" "Build FOD population template (population_template)" \
    "06_batch_fixel_script_populationTemplate.sh"

# -----------------------------------------------------------------------
# Step 7: Registration -> fixel mask -> FD/FC/FDC -> tractography/SIFT ->
#         connectivity -> smoothing -> fixelcfestats
#
#   This script is mostly a commented-out log of sequential sub-stages.
#   On a new dataset, open 07_batch_fixel_script_statisticalAnalysisFWE.sh
#   and uncomment/run each sub-stage in order:
#     1. mrregister (subject -> template warps)
#     2. mrtransform masks + mrmath min  -> template_mask.mif
#     3. fod2fixel on template           -> fixel_mask/
#     4. mrtransform FODs to template space (no reorientation)
#     5. fod2fixel per subject           -> fd.mif
#     6. fixelreorient
#     7. fixelcorrespondence             -> template/fd/
#     8. warp2metric -fc + log transform -> template/fc/, template/log_fc/
#     9. mrcalc fd*fc                    -> template/fdc/
#    10. tckgen (whole-brain tractography, 20M streamlines)
#    11. tcksift                         -> tracks_*_sift.tck
#    12. fixelconnectivity               -> matrix/   (large memory!)
#    13. fixelfilter smooth (fd, log_fc, fdc)
#    14. fixelcfestats (fd, log_fc, fdc) using design/contrast matrices
#
#   As checked in, only the connectivity + smoothing steps (12-13) and the
#   trailing `cd ../template` run by default.
# -----------------------------------------------------------------------
run_step "7" "Registration, fixel metrics, connectivity, smoothing, stats" \
    "07_batch_fixel_script_statisticalAnalysisFWE.sh"

# -----------------------------------------------------------------------
# Step 8: Generate spherical "inter-effector region" (IER) ROI masks
#   Run BEFORE step 9 if step 9's tckedit calls reference these masks.
#   Edit the x/y/z/r coordinates inside the script for your ROIs.
# -----------------------------------------------------------------------
run_step "8" "Generate spherical ROI (IER) masks" \
    "09_batch_generate_IER_masks.sh"

# -----------------------------------------------------------------------
# Step 9: Extract ROI/tract-specific streamlines from the SIFT tractogram
#   Edit to keep only the tckedit lines for the ROIs/tracts you need;
#   the mrview call at the end is for visual inspection only.
# -----------------------------------------------------------------------
run_step "9" "Extract ROI/tract-specific streamlines (tckedit)" \
    "08_batch_fixel_script_ROI_tracts_through_IFG.sh"

# -----------------------------------------------------------------------
# Step 10: Summarise FD/FC/FDC (raw + smoothed) statistics within a fixel
#   mask to text files. Update the "RC1" prefix and mask path inside the
#   script for your ROI/cohort before running.
# -----------------------------------------------------------------------
run_step "10" "Print summary statistics (mrstats)" \
    "10_batch_print_stats_results.sh"

echo
echo "============================================================"
echo "Pipeline run complete (or stopped at requested step)."
echo "Optional utilities (run manually, NOT part of this script):"
echo "  - XX_batch_vf_generation.sh   : build per-subject vf.mif for visualisation"
echo "  - XX_batch_remove_files.sh    : remove a named subfolder from all subjects"
echo "  - XX_batch_cleanup.sh         : DESTRUCTIVE - strip subjects down to essentials"
echo "============================================================"

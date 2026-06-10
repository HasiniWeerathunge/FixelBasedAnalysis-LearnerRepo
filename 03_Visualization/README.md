# Visualization — Post-Stats Fixel Visualization & Extraction

This folder contains the scripts used **after** `fixelcfestats` (step 7 of
`MercuryShellScripts`) to turn raw statistical fixel maps
(`fwe_1mpvalue.mif`, `uncorrected_pvalue.mif`) into significance masks,
track-visualisation files, spatial clusters, and per-subject CSVs used for
plotting (see `Figure_generation/`).

All scripts operate on the output of a **single statistical contrast** at a
time (e.g. `stats_log_fc_centered_Group_negative`,
`stats_log_fc_centered_InteractionGroupAge_negative`). The contrast/folder
name is set near the top of each script via a `STATS_DIR` variable — edit
this (and `OUT_DIR`) for the contrast you want to process before running.

A `master_visualization_pipeline.sh` is included that walks through the
steps below in order for a given `STATS_DIR`.

---

## Pipeline overview

| Step | Script | Purpose |
|------|--------|---------|
| 1 | `tsfscript.sh` | Threshold stats maps to significance masks + generate `.tsf` track-scalar files for `mrview` |
| 2 | `ClusteringSigFixels.sh` | Convert significant fixels to voxels and spatially cluster them (AFNI `3dclust`) |
| 3 | `Cluster_meanlogFC_extraction.sh` | Per-subject mean logFC within each uncorrected-p cluster → CSV |
| 4 | `mean_log_fc_generation.sh` | Per-subject, per-tract mean logFC (whole tract + significant subsets) → CSV |
| 5 | `mean_log_fc_generation_wholebrain.sh` | Per-subject whole-brain mean logFC (whole brain + significant subsets) → CSV |
| 6 | `tractOverlapSig*.sh` | Overlap between significant fixels/clusters and predefined tract masks → CSV |

---

## Step-by-step details

### 1. `tsfscript.sh` — Significance masks & track visualisation
For a chosen `STATS_DIR` (set at the top of the script — only one
`STATS_DIR=` line should be uncommented at a time), thresholds:

- `fwe_1mpvalue.mif` at `0.95` → `sigmask_FWE_05.mif` (PFWE < 0.05)
- `fwe_1mpvalue.mif` at `0.995` → `sigmask_FWE_005.mif` (PFWE < 0.005)
- `uncorrected_pvalue.mif` at `0.999` → `sigmask_unc_001.mif` (Punc < 0.001)
- `uncorrected_pvalue.mif` at `0.995` → `sigmask_unc_005.mif` (Punc < 0.005)

then runs `fixel2tsf` against `tracks_20k_sift_LAS.tck` to produce `.tsf`
track-scalar files for each mask, for visualisation of significant tracks
in `mrview`.

- **Input:** `$STATS_DIR/fwe_1mpvalue.mif`, `$STATS_DIR/uncorrected_pvalue.mif`,
  `tracks_20k_sift_LAS.tck`
- **Output:** `$STATS_DIR/sigmask_*.mif`, `$STATS_DIR/group_effect_*_20ktracks.tsf`

### 2. `ClusteringSigFixels.sh` — Spatial clustering of significant fixels
Thresholds `fwe_1mpvalue.mif` at PFWE < 0.05, binarises it, converts the
fixel mask to a voxel image (`fixel2voxel`) and then NIfTI, and runs AFNI's
`3dclust` (NN3 connectivity) to label spatially contiguous clusters,
producing one binary mask per cluster (`cluster_<i>.nii.gz`). A second block
does the same for an "uncorrected p<0.001, MNI space" mask
(`clustered_mask_unc_001_MNI_3dclust.nii.gz` → `cluster_MNI_<i>.nii.gz`).

- **Requires:** `mrtrix` and `afni` modules.
- **Note:** the script references `sigmask_unc_005_bin_voxel.nii` /
  `sigmask_unc_001_bin_voxel_MNI.nii` in the `3dclust` calls without first
  generating them in this script — generate these voxel masks (following
  the same `mrthreshold` → `mrcalc -gt` → `fixel2voxel` → `mrconvert`
  pattern as the FWE example at the top) before running those lines.

### 3. `Cluster_meanlogFC_extraction.sh` — Per-cluster mean logFC
For each subject's smoothed log-FC image and each `unc_001_cluster_<i>`
mask produced in step 2, binarises the cluster mask and computes the mean
logFC within it via `mrstats`.

- **Input:** `$SUBJECT_DIR/*_1.mif` (per-subject log-FC), `$STATS_DIR/unc_001_cluster_<i>/unc_001_cluster_<i>.mif`
- **Output:** `$OUT_DIR/cluster_mean_logFC_per_subject.csv` (columns:
  `Subject, Cluster, Threshold, Mean_logFC`)
- **Note:** edit `SUBJECT_DIR`, `STATS_DIR`, `OUT_DIR` at the top before
  running. This CSV feeds `Figure_generation/Cluster_scatterPlots.R` and the
  `Clusters_Fig2_*` scripts.

### 4. `mean_log_fc_generation.sh` — Per-tract mean logFC
For each tract fixel mask in `$TRACT_DIR` (e.g.
`tract_based_analysis/fixel_mask_tracts_selected/*_fixel_mask.mif`):

1. Thresholds that tract's stats (`$STATS_DIR/tracts/<tract>_fixel_mask/`)
   into FWE 0.05/0.005 and uncorrected 0.001/0.0025/0.005 significance masks,
   and generates the corresponding `.tsf` files.
2. For every subject listed in `files_n171_March2026.txt`, computes the mean
   logFC within: the whole tract, and each significance mask (writing `NA`
   if a mask contains zero significant fixels).

- **Input:** `log_fc_smooth/*.mif`, `$TRACT_DIR/*_fixel_mask.mif`,
  `$STATS_DIR/tracts/<tract>_fixel_mask/{fwe_1mpvalue,uncorrected_pvalue}.mif`,
  `files_n171_March2026.txt`
- **Output:** `$OUT_DIR/SIG_mean_logFC_<tract>.csv` (per tract) and
  `$OUT_DIR/SIG_mean_logFC_all.csv` (combined, long format)
- **Note:** edit `TRACT_DIR`, `STATS_DIR`, `OUT_DIR` for the contrast/run.
  These CSVs feed most of the `Figure_generation/BarPlots_*` and
  `ScatterPlots_*` scripts.

### 5. `mean_log_fc_generation_wholebrain.sh` — Whole-brain mean logFC
Same as step 4 but without restricting to tract masks — thresholds the
whole-brain `$STATS_DIR/{fwe_1mpvalue,uncorrected_pvalue}.mif`, generates
`.tsf` files, and computes per-subject mean logFC over the whole brain and
within each whole-brain significance mask.

- **Output:** `$OUT_DIR/SIG_mean_logFC_WholeBrain.csv`
- **Note:** edit `STATS_DIR`, `OUT_DIR` for the contrast/run. This CSV is
  combined with the per-tract CSV from step 4 (as the "WholeBrain" row) in
  the `Figure_generation` scripts.

### 6. `tractOverlapSig*.sh` — Tract / significant-fixel overlap
Computes how much of each tract overlaps with the significant fixels from a
contrast. There are three versions, in increasing order of refinement —
**use the latest unless you need to reproduce an earlier figure**:

- **`tractOverlapSig.sh`** (original): for each tract, binarises the
  whole-brain FWE/uncorrected significance masks, computes total fixels per
  tract and per significance mask, computes the overlap
  (`mrcalc ... -and`) between the tract mask and each significance mask, and
  writes counts/percentages to `OUT_DIR/OVERLAP_<tract>.csv` and
  `OVERLAP_all.csv`. Configured for `stats_log_fc_centered_Group_negative`.
- **`tractOverlapSig_03232026_clustersVersion.sh`**: reworks the above to
  operate per spatial **cluster** (from step 2/`ClusteringSigFixels.sh`)
  rather than the whole significance mask, restricted to FWE 0.05 and
  uncorrected 0.001. Adds AFNI/FSL module loads and a `FIXEL_DIR` variable.
  Configured for `stats_log_fc_centered_InteractionGroupAge_negative`.
- **`tractOverlapSig_03302026_clustersVersion.sh`** (latest): fixes mask
  binarisation (binarises both the cluster mask and the tract mask before
  `-and`), uses bash arrays to track per-cluster totals/overlaps/percentages,
  and additionally writes a `Whole_brain` summary row per threshold to the
  output CSV.

- **Output:** `$OUT_DIR/OVERLAP_<tract>.csv` and `$OUT_DIR/OVERLAP_all.csv`
- **Note:** edit `TRACT_DIR`, `STATS_DIR`, `OUT_DIR`, `CROPPED_TRACT_DIR` (and
  `FIXEL_DIR` in the cluster versions) for the contrast/run.

---

## Before running on a new contrast

1. Run `fixelcfestats` (MercuryShellScripts step 7) for the contrast of
   interest, producing a `stats_<metric>_<contrast>` directory containing
   `fwe_1mpvalue.mif` and `uncorrected_pvalue.mif` (and per-tract
   subdirectories under `tracts/` if doing tract-level stats).
2. In each script you plan to run, set `STATS_DIR` to that directory and
   `OUT_DIR` to where you want the CSVs/masks written.
3. Run the steps in order using `master_visualization_pipeline.sh`, or
   individually.

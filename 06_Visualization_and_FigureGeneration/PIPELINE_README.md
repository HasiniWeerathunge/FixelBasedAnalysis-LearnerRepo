# Visualization & Figure Generation — Post-Stats Pipeline

This folder combines the two stages that run **after** `fixelcfestats`
(step 7 of `MercuryShellScripts`):

- **Part 1 — Visualization (bash/MRtrix/AFNI)**: turns raw statistical
  fixel maps (`fwe_1mpvalue.mif`, `uncorrected_pvalue.mif`) into
  significance masks, track-visualisation files, spatial clusters, and
  per-subject CSVs.
- **Part 2 — Figure generation (R/ggplot2)**: turns those CSVs into the
  bar charts, raincloud plots, and scatter plots used in the paper.

`master_pipeline.sh` runs Part 1 (interactively, step by step) and then
optionally runs Part 2 via `Rscript`.

---

## Pipeline overview

| Part | Step | Script | Purpose |
|------|------|--------|---------|
| 1 | 1 | `tsfscript.sh` | Threshold stats maps to significance masks + generate `.tsf` track-scalar files for `mrview` |
| 1 | 2 | `ClusteringSigFixels.sh` | Convert significant fixels to voxels and spatially cluster them (AFNI `3dclust`) |
| 1 | 3 | `Cluster_meanlogFC_extraction.sh` | Per-subject mean logFC within each uncorrected-p cluster → CSV |
| 1 | 4 | `mean_log_fc_generation.sh` | Per-subject, per-tract mean logFC (whole tract + significant subsets) → CSV |
| 1 | 5 | `mean_log_fc_generation_wholebrain.sh` | Per-subject whole-brain mean logFC (whole brain + significant subsets) → CSV |
| 1 | 6 | `tractOverlapSig*.sh` | Overlap between significant fixels/clusters and predefined tract masks → CSV |
| 2 | — | `*.R` (see Part 2 below) | Bar/scatter/raincloud figures from the CSVs produced in Part 1 |

All Part 1 scripts operate on the output of a **single statistical
contrast** at a time (e.g. `stats_log_fc_centered_Group_negative`,
`stats_log_fc_centered_InteractionGroupAge_negative`). The contrast/folder
name is set near the top of each script via a `STATS_DIR` variable — edit
this (and `OUT_DIR`) for the contrast you want to process before running.

---

## Part 1 — Visualization: step-by-step details

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
  running. This CSV feeds `Cluster_scatterPlots.R` and the `Clusters_Fig2_*`
  scripts in Part 2.

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
  These CSVs feed most of the `BarPlots_*` and `ScatterPlots_*` scripts in
  Part 2.

### 5. `mean_log_fc_generation_wholebrain.sh` — Whole-brain mean logFC
Same as step 4 but without restricting to tract masks — thresholds the
whole-brain `$STATS_DIR/{fwe_1mpvalue,uncorrected_pvalue}.mif`, generates
`.tsf` files, and computes per-subject mean logFC over the whole brain and
within each whole-brain significance mask.

- **Output:** `$OUT_DIR/SIG_mean_logFC_WholeBrain.csv`
- **Note:** edit `STATS_DIR`, `OUT_DIR` for the contrast/run. This CSV is
  combined with the per-tract CSV from step 4 (as the "WholeBrain" row) by
  the `load_direction()` helper used throughout Part 2.

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

## Part 2 — Figure generation: R scripts

Almost all R scripts read from:

```
/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template_cohort1and2_all/SIG_mean_logFC/
```

This is **not a strict numbered pipeline** — it's a set of figure scripts,
several of which are iterative versions of the same figure (dated in the
filename, e.g. `_03092026`, `_03232026`, `_04172026`). Later dates are more
refined. This section groups scripts by the figure/analysis they produce and
flags the recommended/latest version of each.

### Common inputs (produced by Part 1)

| File | Produced by | Contents |
|------|-------------|----------|
| `mean_logFC_dataset.csv` | manual/demographics export | Subject, Group (0/1), Age (centered), Sex, Site, TIV, SES, VIQ, MotionMeasure, etc. |
| `mean_logFC_dataset_persistent_recovered.csv` | manual/demographics export | As above, plus `Persistent`/`Recovered` indicator columns and SSI-4/SLD severity scores — used by all "PersistantRecovered" scripts |
| `<Contrast>/SIG_mean_logFC_WholeBrain.csv` | Part 1, step 5 | Per-subject whole-brain mean logFC, overall + at each significance threshold |
| `<Contrast>/SIG_mean_logFC_all.csv` | Part 1, step 4 | Per-subject, per-tract mean logFC, overall + at each significance threshold |
| `cluster_mean_logFC_per_subject.csv` | Part 1, step 3 | Per-subject, per-cluster (uncorrected p<0.001) mean logFC |

`<Contrast>` is a folder name like `Group_effect_positive`,
`Group_effect_negative`, `GroupAgeInteraction_positive`,
`GroupAgeInteraction_negative`, etc. — the output of one
`fixelcfestats` contrast processed by Part 1.

### Common pattern: `load_direction()` and threshold hierarchy

Most scripts (from `BarPlots_03112026.R` onward) define:

```r
load_direction <- function(folder, direction){
  wb <- read.csv(paste0(folder,"/SIG_mean_logFC_WholeBrain.csv")) %>% mutate(Tract="WholeBrain")
  tracts <- read.csv(paste0(folder,"/SIG_mean_logFC_all.csv"))
  bind_rows(wb, tracts) %>% mutate(Direction=direction)
}
all_data <- load_direction("Group_effect_positive","Positive")
```

then pivot the per-threshold columns (FWE<0.05, FWE<0.005, unc<0.001,
unc<0.0025, unc<0.005, plus the unthresholded "All") into long format, merge
with demographics, define a **threshold hierarchy** (FWE_05 > FWE_005 >
unc_001 > unc_0025 > unc_005 > All), and pick the **highest available
threshold per tract** to plot. To switch which contrast/direction a script
plots, edit the `load_direction(...)` call (other options are left as
commented-out alternatives).

### Figure families

#### A. Whole-brain + per-tract bar/raincloud plots ("BarPlots" series)
Group comparison bar charts of mean logFC (whole brain + each tract) at the
highest significant threshold. Iteration history, oldest to newest:

1. `BarPlots_03092026.R` / `BarPlots_03102026.R` — earliest versions, near
   duplicates. Load positive+negative effects separately, pivot thresholds,
   merge `mean_logFC_dataset.csv`, plot grouped bar/box plots (Control vs
   Stuttering). `ggsave` calls present but commented out.
2. `BarPlots_03112026.R` — refactor: introduces `load_direction()`, the
   threshold hierarchy, and "highest threshold per tract" logic reused by
   later scripts. Title: *"Group Differences in Mean Fiber Cross-Section
   (logFC)"*.
3. `BarPlots_03202026_PersistantRecovered.R` — switches demographics to
   `mean_logFC_dataset_persistent_recovered.csv` and splits the Stuttering
   group into **Persistent** vs **Recovered** (3-group comparison vs
   Control).
4. `BarPlots_03232026_PersistantRecovered_siglevelsOnly.R` — adds a filter
   to keep only tracts that have significant fixels at the required
   threshold (drops non-significant tracts from the figure).
5. `BarPlots_04172026_ControlStutt_siglevelsOnly.R` — collapses
   Persistent/Recovered back into a single "Stuttering" group, adds a
   per-tract GLM ("MATCHES MAIN MODEL") for significance annotation.
6. `BarPlots_04172026_ControlStutt_residual_siglevelsOnly.R` — as above, but
   computes **covariate-adjusted residuals** (regressing out Sex, Site, TIV,
   SES, VIQ, MotionMeasure — everything except Group) before plotting/GLM.
7. `BarPlots_04172026_ControlStutt_residual_raincloud_siglevelsOnly.R`
   (**recommended for Control-vs-Stuttering bar/raincloud figures**) — same
   residualization + GLM as #6, plus a raincloud (`ggdist`) plot of the
   residualized values.
8. `BarPlots_04172026_persist_GLM.R` — "ROBUST VERSION" GLM, back on the
   Persistent/Recovered/Control 3-group dataset, per-tract GLM + summary bar
   plot (no residualization/raincloud).

**Use #7 for the Control-vs-Stuttering figure and #8 for the
Persistent/Recovered 3-group figure**; #1–#6 are kept for reference/history.

#### B. Cluster-level scatter plots ("Fig2" / cluster scripts)
Scatter plots of per-cluster mean logFC (from
`cluster_mean_logFC_per_subject.csv`) vs. Age, faceted/colored by Group.

- `Cluster_scatterPlots.R` — base version: loops over clusters, scatter vs
  Age, `ggsave` commented out.
- `Clusters_Fig2_Age_Group_covariate_corrected.R` — adds covariate
  correction before plotting (Age & Group focus). **Recommended for the
  Age×Group cluster figure (Fig2).**
- `Clusters_Fig2_SSI4_Group_covariatecorrected.R` — variant that removes the
  Control group and focuses on the Stuttering group's SSI-4 severity score
  vs. cluster logFC.

#### C. Tract-level Fig3/Fig4 bar + scatter plots
- `Fig3_Barcharts_threegroups.R` — three-group (Control/Persistent/Recovered)
  raincloud plots with a data-driven ROI/tract selection step.
- `Fig3_barplots.R` — combined bar + raincloud plot, "STYLE MATCHED" to the
  BarPlots series (residualized + GLM, like family A #7 but tract-focused).
- `Fig_2_4_Scatter_plots_AgeGroup.R` — per-tract scatter of logFC vs Age,
  colored by Group ("MATCH CLUSTER SCRIPT" — mirrors family B's plot style
  but for tracts instead of clusters).
- `Tracts_Fig3and4_SSI_logFC_scatterPlots.R` — per-tract scatter of logFC vs
  SSI-4 severity ("NOW MATCHES CLUSTER STYLE").

These four together produce the tract-level panels of Fig3/Fig4 paired with
the cluster-level panels from family B.

#### D. Residualized scatter plots vs. SSI/SLD severity
- `Residual_ScatterPlots_forSSI_SLD_03232026_persistantRecovered_sigOnly.R`
  — residualizes logFC against covariates (Sex, Site, TIV, SES, VIQ, Motion
  — NOT Group or SSI), then plots residual logFC vs SSI-4/SLD severity,
  per Group.
- `Residual_interactionModel_ScatterPlots_forSSI_SLD_03232026_persistantRecovered_sigOnly.R`
  — same residualization, but additionally fits a Group×severity
  **interaction model** and plots fitted interaction lines.

Use the interaction-model version if testing/illustrating whether the
brain–severity association differs by group; use the simpler version for a
plain per-group scatter.

#### E. General `ScatterPlots*` series
- `ScatterPlots.R` — different working directory
  (`mean_logFC_per_tract/dataset.csv`, not `SIG_mean_logFC/`). Residualizes
  each of a fixed set of tract columns (ATRleft/right, CC, CSTleft/right,
  ILFright, STRleft/right) against Sex/Site/TIV/SES/VIQ/Motion, then makes
  per-tract Age scatter plots ("Group × Age: <tract>") plus a combined
  "Group × Age Interaction" plot. **Has a real (uncommented) `ggsave()` call**
  — appears to be an earlier, self-contained exploratory script using a
  differently-structured dataset than the rest of this folder.
- `ScatterPlots_03122026.R` — `SIG_mean_logFC`-based version using
  `mean_logFC_dataset.csv` (Control/Stuttering only, no Persistent/Recovered),
  full threshold-hierarchy + tract-ordering pipeline, ends in a scatter plot
  loop.
- `ScatterPlots_forAge_03232026_persistantRecovered_sigOnly.R` — same
  pipeline as the BarPlots `_sigOnly` family, plotting mean logFC vs Age
  (predictor variable selectable).
- `ScatterPlots_forSSI_SLD_03122026.R` — earlier (Control/Stuttering only)
  version of the SSI/SLD scatter plots, with group-specific correlation
  labels.
- `ScatterPlots_forSSI_SLD_03232026_persistantRecovered_sigOnly.R` and
  `ScatterPlots_forssi03232026_persistantRecovered_sigOnly.R` — two
  near-identical Persistent/Recovered, sig-levels-only versions of the
  SSI/SLD scatter plot (`labs(title = ..., x = "Stuttering Severity
  (SSI-4)", y = "Mean log Fiber Cross-Section")`); the
  `ScatterPlots_forSSI_SLD_...` (capital SSI) file is the more
  consistently-named/likely final one — treat
  `ScatterPlots_forssi03232026_...` as a duplicate kept for reference.

#### F. Mixed-effects Age×Group interaction
- `age_group_interaction_04212026.R` — fits `lme4`/`lmerTest` mixed-effects
  models (Age × Group, with subject-level random effects) on whole-brain and
  per-tract mean logFC, filters to "valid" tracts with sufficient data, and
  produces a whole-brain global-trend plot plus per-tract plots. Also
  reports which tracts were excluded and why.

#### G. Standalone snippet
- `meanFC_barPlots.R` — short (45-line) standalone script that **assumes a
  pre-existing `df` data frame** with columns `Group, AF_meanFC, SLF_meanFC,
  CST_meanFC`, reshapes to long format, and saves
  `Figure2_tracts_meanFC.png`. Not wired to the `SIG_mean_logFC` CSVs used by
  everything else — likely an early prototype/snippet for a multi-panel bar
  chart. Keep as reference; needs `df` to be constructed first if reused.

### Recommended figure set (used by `master_pipeline.sh`)

| Figure | Script |
|--------|--------|
| Group bar/raincloud (Control vs Stuttering) | `BarPlots_04172026_ControlStutt_residual_raincloud_siglevelsOnly.R` |
| Group bar (Persistent/Recovered/Control, GLM) | `BarPlots_04172026_persist_GLM.R` |
| Fig2 cluster scatter (Age × Group) | `Clusters_Fig2_Age_Group_covariate_corrected.R` |
| Fig2 cluster scatter (SSI-4, Stuttering only) | `Clusters_Fig2_SSI4_Group_covariatecorrected.R` |
| Fig3/4 tract bar + raincloud | `Fig3_barplots.R` |
| Fig3/4 tract scatter (Age × Group) | `Fig_2_4_Scatter_plots_AgeGroup.R` |
| Fig3/4 tract scatter (SSI-4) | `Tracts_Fig3and4_SSI_logFC_scatterPlots.R` |
| Residual scatter vs SSI/SLD (interaction model) | `Residual_interactionModel_ScatterPlots_forSSI_SLD_03232026_persistantRecovered_sigOnly.R` |
| Mixed-effects Age × Group | `age_group_interaction_04212026.R` |

All other scripts are earlier iterations, kept for reference/reproducing
older figure versions.

---

## Before running on a new contrast

1. Run `fixelcfestats` (MercuryShellScripts step 7) for the contrast of
   interest, producing a `stats_<metric>_<contrast>` directory containing
   `fwe_1mpvalue.mif` and `uncorrected_pvalue.mif` (and per-tract
   subdirectories under `tracts/` if doing tract-level stats).
2. In each Part 1 script you plan to run, set `STATS_DIR` to that directory
   and `OUT_DIR` to where you want the CSVs/masks written.
3. Make sure the CSVs from Part 1 exist for every contrast folder referenced
   by the Part 2 scripts you plan to run (`Group_effect_positive/negative`,
   `GroupAgeInteraction_positive/negative`, etc.) under `SIG_mean_logFC/`.
4. Each R script hard-codes `setwd(...)` to the cluster path
   `/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template_cohort1and2_all/SIG_mean_logFC/`
   (except `ScatterPlots.R`, which uses `mean_logFC_per_tract/`) — update
   this if running locally or on a different mount.
5. Most `ggsave()` calls are commented out (scripts were run interactively
   and plots inspected in RStudio). Uncomment/add `ggsave()` calls where you
   want PNG/PDF output written.
6. R packages required: `dplyr`, `tidyr`, `ggplot2`, `ggdist`, `broom`,
   `lme4`, `lmerTest`.
7. Run the steps in order using `master_pipeline.sh`, or individually.

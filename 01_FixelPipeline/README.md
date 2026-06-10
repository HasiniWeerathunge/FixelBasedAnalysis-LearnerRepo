# MercuryShellScripts — Fixel-Based Analysis Pipeline

This folder contains the batch scripts used to run the MRtrix3 fixel-based
analysis (FBA) pipeline on the Mercury cluster. Scripts are numbered in the
order they are meant to be run. All numbered scripts assume MRtrix3 (and for
step 4, the `mrtrix/tissue` / 3-Tissue module) is loaded via `module load`,
and that `parent_dir` points to the folder containing one subdirectory per
subject, each holding that subject's `dwi.mif` and `mask.mif`.

A `master_pipeline.sh` script is included that calls each step in sequence.
Because several steps require manual decisions (selecting template subjects,
visual QC, choosing ROI coordinates) or are cluster jobs that take hours,
the master script is best used as an annotated reference / runner that you
step through rather than a fully unattended one-shot job — see the notes in
each section below and in the script's comments.

---

## Pipeline overview

| Step | Script | Purpose |
|------|--------|---------|
| 1 | `01_batch_fixel_script_responsefunction.sh` | Per-subject response function estimation |
| 2 | `02_batch_fixel_script_responseGroupAverage.sh` | Group-average response functions |
| 3 | `03_batch_fixel_script_resizeMask.sh` | Upsample brain masks to 1.25 mm |
| 4 | `04_batch_fixel_script_SSMT_CSD.sh` (or `batch_fixel_parallel_*.sh`) | Single-Shell 3-Tissue CSD (FOD estimation) |
| 5 | `05_batch_fixel_script_biasTX_nonrmalize.sh` | Joint bias-field correction & intensity normalisation |
| QA1 | `QA1_batch_QA1_mrview.sh` | Visual QC of upsampled brain masks |
| 6 | `06_batch_fixel_script_populationTemplate.sh` | Build the study-specific FOD population template |
| 7 | `07_batch_fixel_script_statisticalAnalysisFWE.sh` | Registration → fixel mask → FD/FC/FDC → tractography/SIFT → connectivity → smoothing → `fixelcfestats` |
| 8 | `08_batch_fixel_script_ROI_tracts_through_IFG.sh` | Extract ROI/tract-specific streamlines from the SIFT tractogram |
| 9 | `09_batch_generate_IER_masks.sh` | Generate spherical ROI masks (e.g. inferior/middle/superior effector regions) in template space |
| 10 | `10_batch_print_stats_results.sh` | Summarise FD/FC/FDC (and smoothed) statistics within a fixel mask to text files |
| Utility | `XX_batch_cleanup.sh` | Delete intermediate files/subfolders, keeping only essentials |
| Utility | `XX_batch_remove_files.sh` | Remove a specific named subfolder (e.g. `fixel_in_template_space`) from every subject |
| Utility | `XX_batch_vf_generation.sh` | Build a combined WM/GM/CSF "vf" (tissue fraction) image per subject for visualisation |

---

## Step-by-step details

### 1. `01_batch_fixel_script_responsefunction.sh` — Response function estimation
Runs `dwi2response dhollander` on every subject folder to estimate
subject-specific white matter, grey matter and CSF response functions.

- **Input:** `IN/dwi.mif`
- **Output:** `IN/response_wm.txt`, `IN/response_gm.txt`, `IN/response_csf.txt`
- **Note:** `parent_dir` in this script points at `subjects_cohort1` — update
  to the relevant cohort folder before running on a new dataset.

### 2. `02_batch_fixel_script_responseGroupAverage.sh` — Group-average response
Averages each subject's response functions into single group-level response
functions used for CSD in step 4.

- **Input:** `*/response_{wm,gm,csf}.txt`
- **Output:** `../group_average_response_{wm,gm,csf}_cohort2.txt`
- **Note:** rename the output suffix (`_cohort2`) as appropriate for your
  cohort/run.

### 3. `03_batch_fixel_script_resizeMask.sh` — Upsample masks
Regrids each subject's brain mask to 1.25 mm isotropic resolution to match
the upsampled DWI data.

- **Input:** `IN/mask.mif`
- **Output:** `IN/mask_upsampled.mif`
- **Note:** the commented-out lines show the earlier (one-time) steps of
  upsampling the DWI itself (`mrgrid ... dwi_upsampled.mif`) and generating
  `dwi_mask_upsampled.mif` via `dwi2mask` — run those first if they don't
  already exist for this dataset.

### 4. `04_batch_fixel_script_SSMT_CSD.sh` — Single-Shell 3-Tissue CSD
Runs `ss3t_csd_beta1` (3-Tissue / `mrtrix/tissue`) per subject, in parallel
(N=64 background jobs), using the group-average response functions from
step 2 to produce per-subject WM/GM/CSF FODs.

- **Input:** `IN/dwi_upsampled.mif`, `IN/dwi_mask_upsampled.mif`,
  `group_average_response_*_cohort2.txt`
- **Output:** `IN/wmfod.mif`, `IN/gmfod.mif`, `IN/csffod.mif`
- **Note:** the line `N = 64` is invalid bash (`N=64` with no spaces is
  required) — fix this before running.
- **Cohort/group variants:** `batch_fixel_parallel_NF.sh`,
  `batch_fixel_parallel_NM.sh`, `batch_fixel_parallel_SF.sh`,
  `batch_fixel_parallel_SM.sh` are alternative versions of this step that
  run the same `ss3t_csd_beta1` command over subgroup-specific subject
  folders (`subjects_subset_NF/NM/SF/SM`) with a throttled `MAX_JOBS=4`
  parallel loop and a non-suffixed response function name
  (`group_average_response_*.txt`). Use these when processing the four
  subgroups separately instead of (or in addition to) script 4.

### 5. `05_batch_fixel_script_biasTX_nonrmalize.sh` — Bias correction & normalisation
Runs `mtnormalise` per subject for joint bias-field correction and intensity
normalisation across the WM/GM/CSF FODs.

- **Input:** `IN/wmfod.mif`, `IN/gmfod.mif`, `IN/csffod.mif`,
  `IN/dwi_mask_upsampled.mif`
- **Output:** `IN/wmfod_norm.mif`, `IN/gmfod_norm.mif`, `IN/csffod_norm.mif`

### QA1. `QA1_batch_QA1_mrview.sh` — Visual QC of masks
Opens each subject's `dwi_mask_upsampled.mif` in `mrview`, one at a time,
pausing for the user to press Enter before moving to the next subject.
Use this to confirm masks cover all brain regions needed for the analysis
(important because regions excluded from any one subject's mask are
excluded from the template/group analysis).

- **Interactive — not suitable for unattended/batch execution.**

### 6. `06_batch_fixel_script_populationTemplate.sh` — Population FOD template
Symlinks every subject's normalised WM FOD (`wmfod_norm.mif`) and upsampled
mask into shared `../template/fod_input` and `../template/mask_input`
folders, then runs `population_template` to build a study-specific unbiased
FOD template at 1.25 mm.

- **Input:** `IN/wmfod_norm.mif`, `IN/dwi_mask_upsampled.mif` (all subjects)
- **Output:** `../template/wmfod_template.mif`
- **Note:** the commented-out blocks show how to instead build the template
  from a balanced subset (top 10 subjects per group, by sort order) rather
  than the full population — uncomment/adjust if a subset template is
  preferred.

### 7. `07_batch_fixel_script_statisticalAnalysisFWE.sh` — Registration, fixel metrics & stats
This script is a working log of the rest of the core FBA pipeline. Most
lines are commented out because each stage was run separately (and some are
extremely memory/time intensive). In order, the stages are:

1. Register each subject's `wmfod_norm.mif` to the population template
   (`mrregister` → `subject2template_warp.mif`, `template2subject_warp.mif`)
2. Warp each subject's mask into template space and intersect (`mrtransform`
   + `mrmath ... min`) → `../template/template_mask.mif`
3. Segment fixels from the FOD template (`fod2fixel`) → `../template/fixel_mask`
4. Warp each subject's FOD into template space without reorientation
   (`mrtransform ... -reorient_fod no`)
5. Segment subject FODs in template space to get per-subject fibre density
   (FD) fixels (`fod2fixel ... -afd fd.mif`)
6. Reorient subject fixels (`fixelreorient`)
7. Match subject fixels to template fixels (`fixelcorrespondence`) →
   `../template/fd/`
8. Compute the fibre cross-section (FC) metric (`warp2metric -fc`) →
   `../template/fc/`, then log-transform → `../template/log_fc/`
9. Compute the combined fibre density & cross-section (FDC) metric
   (`mrcalc fd * fc`) → `../template/fdc/`
10. Whole-brain probabilistic tractography on the template (`tckgen`,
    20 million streamlines)
11. SIFT to reduce tractogram bias (`tcksift` → 1M and/or 2M streamlines)
12. Build the fixel-fixel connectivity matrix (`fixelconnectivity`) —
    **large memory requirement**
13. Smooth FD, log-FC and FDC fixel data using the connectivity matrix
    (`fixelfilter ... smooth`)
14. Run the statistical analysis (`fixelcfestats`) for FD, log-FC and FDC
    against `design_matrix*.txt` / `contrast_matrix*.txt` (see
    `FA_analysis/tbss_analysis/design_*` for example design/contrast files)

- **Note:** as written, the only lines that execute by default are the final
  `fixelconnectivity`, `fixelfilter` (x3), and the `cd ../template`. The
  earlier registration/fixel-mask/FD/FC/FDC steps and the final
  `fixelcfestats` calls are commented out and were run as separate jobs —
  uncomment and run each block in order on first use for a new dataset.
- All steps use `-nthreads 48`.

### 8. `08_batch_fixel_script_ROI_tracts_through_IFG.sh` — ROI/tract extraction
From inside `../template`, uses `tckedit -include <mask>` to pull
streamlines passing through specific ROI masks (e.g. IFG cluster masks,
inter-effector region masks from step 9) out of the SIFT tractogram, then
visualises the result with `mrview`.

- **Input:** `tracks_1_million_sift.tck`, ROI masks (e.g.
  `mask_Left_Cluster1_templatespace.mif`, `roi_il_templatespace.mif`)
- **Output:** per-ROI `.tck` files (e.g. `tracks_1_million_sift_il.tck`)
- **Note:** most lines are example/commented-out invocations for different
  ROIs/clusters — keep only the ones relevant to the ROIs you generated, and
  the trailing `mrview` call is for visual inspection only (not needed for
  batch runs).

### 9. `09_batch_generate_IER_masks.sh` — Spherical ROI ("IER") mask generation
Generates a deformation field for the template (`warpinit`) and then builds
six spherical ROI masks at fixed MNI coordinates using `mrcalc`
(stack-based sphere formula): superior/middle/inferior, left/right
"inter-effector region" (IER) masks.

- **Input:** `MNI152_T1_1mm_Brain.mif`
- **Output:** `roi_sl.mif`, `roi_sr.mif`, `roi_ml.mif`, `roi_mr.mif`,
  `roi_il.mif`, `roi_ir.mif`
- **Note:** edit the `x*/y*/z*/r*` coordinate/radius variables to match the
  ROI(s) you need; these masks feed into step 8's `tckedit -include`.

### 10. `10_batch_print_stats_results.sh` — Summary statistics
For each `.mif` file in the (smoothed and unsmoothed) `fd`, `fdc`, and
`log_fc` template directories, computes mean/median/std/std_rv/min/max/count
within a fixel mask using `mrstats`, and appends the results to per-metric
text files.

- **Input:** `template/{fd,fdc,log_fc,fd_smooth,fdc_smooth,log_fc_smooth}_withoutindex/*`,
  mask `../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif`
- **Output:** `../RC1_{fd,fdc,logfc,fdsmooth,fdcsmooth,logfcsmooth}_stats.txt`
- **Note:** update the `RC1` prefix and mask path for other ROIs/cohorts.

---

## Utility scripts (run as needed, not part of the main sequence)

- **`XX_batch_cleanup.sh`** — For each subject folder, deletes every file
  except `dwi.mif`, `mask.mif`, `response_{wm,gm,csf}.txt`,
  `dwi_mask_upsampled.mif`, `dwi_upsampled.mif`, `mask_upsampled.mif`, and
  removes all subfolders. **Destructive** — only run once template-space
  outputs have been safely copied elsewhere.
- **`XX_batch_remove_files.sh`** — Removes a specific named subfolder
  (default `fixel_in_template_space`) from every subject folder under
  `subjects_cohort1`. Edit `TARGET_FILE` and `parent_dir` as needed.
- **`XX_batch_vf_generation.sh`** — Builds a combined tissue-fraction image
  (`vf.mif`) per subject by concatenating the l=0 term of `wmfod.mif` with
  `csffod.mif` and `gmfod.mif`, useful for visualising tissue segmentation
  with `mrview -odf.load_sh`.

---

## Before running on a new dataset

All scripts hard-code absolute paths (e.g.
`/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/subjects`) and
sometimes dataset-specific suffixes (`_cohort2`, `RC1`, etc.). Review and
update the `parent_dir`, response-function filenames, and output suffixes
in each script before use. `master_pipeline.sh` centralises the most
commonly-changed values at the top so you only need to edit them in one
place when wiring the steps together.

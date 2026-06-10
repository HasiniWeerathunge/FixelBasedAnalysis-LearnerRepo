

##### Make sure to reorient the wmfod_template that was transformed to MNI space to -strides -1,2,3  

https://community.mrtrix.org/t/extracting-fd-fc-and-fdc-using-tractseg/7790

remember to reorient your data into FSL’s standard orientation space early in your dMRI analysis (with `fslreorient2std` or `mrconvert -strides -1,2,3`) as TractSeg requires your data to be in that orientation. See here: [GitHub - MIC-DKFZ/TractSeg: Automatic White Matter Bundle Segmentation](https://github.com/MIC-DKFZ/TractSeg?tab=readme-ov-file#aligning-image-to-mni-space)


```shell

mrconvert wmfod_template_MNI.mif -strides -1,2,3 wmfod_template_MNI_reoriented.mif

```

### BEFORE

```shell

mrinfo wmfod_template_MNI.mif 
************************************************
Image name:          "wmfod_template_MNI.mif"
************************************************
  Dimensions:        140 x 174 x 125 x 45
  Voxel size:        1.30608 x 1.35526 x 1.33685 x 12.8
  Data strides:      [ -2 3 4 1 ]
  Format:            MRtrix
  Data type:         32 bit float (little endian)
  Intensity scaling: offset = 0, multiplier = 1
  Transform:               0.9994     0.02029  -0.0009451      -90.24
                         -0.02301      0.9945      0.1137      -119.1
                          0.02506     -0.1024      0.9935       -50.4
  command_history:   /app/apps/rhel8/mrtrix/3.0.4/bin/population_template ../template/fod_input -mask_dir ../template/mask_input ../template/wmfod_template.mif -voxel_size 1.25 -nthreads 64 -nocleanup  (version=3.0.4)
                     mrtransform wmfod_template.mif wmfod_template_MNI.mif -linear FOD_to_MNI_affine.txt -reorient_fod yes  (version=3Tissue_v5.2.9)
  comments:          transform modified
  mrtrix_version:    3Tissue_v5.2.9

```

### AFTER

```shell

mrinfo wmfod_template_MNI_reoriented.mif 
************************************************
Image name:          "wmfod_template_MNI_reoriented.mif"
************************************************
  Dimensions:        140 x 174 x 125 x 45
  Voxel size:        1.30608 x 1.35526 x 1.33685 x 12.8
  Data strides:      [ -1 2 3 4 ]
  Format:            MRtrix
  Data type:         32 bit float (little endian)
  Intensity scaling: offset = 0, multiplier = 1
  Transform:               0.9994     0.02029  -0.0009451      -90.24
                         -0.02301      0.9945      0.1137      -119.1
                          0.02506     -0.1024      0.9935       -50.4
  command_history:   /app/apps/rhel8/mrtrix/3.0.4/bin/population_template ../template/fod_input -mask_dir ../template/mask_input ../template/wmfod_template.mif -voxel_size 1.25 -nthreads 64 -nocleanup  (version=3.0.4)
                     mrtransform wmfod_template.mif wmfod_template_MNI.mif -linear FOD_to_MNI_affine.txt -reorient_fod yes  (version=3Tissue_v5.2.9)
                     mrconvert wmfod_template_MNI.mif -strides '-1,2,3' wmfod_template_MNI_reoriented.mif  (version=3.0.4)
  comments:          transform modified
  mrtrix_version:    3.0.4

```


https://github.com/MIC-DKFZ/TractSeg/issues/167

```shell

sh2peaks wm_fod_template.mif peaks.nii.gz  
#got a warning
sh2peaks: [WARNING] image "peaks.nii.gz" contains non-rigid transform -qform will not be stored.


TractSeg -i peaks.nii.gz --output_type tract_segmentation  
TractSeg -i peaks.nii.gz --output_type endings_segmentation  
TractSeg -i peaks.nii.gz --output_type TOM  
Tracking -i peaks.nii.gz --tracking_format tck
#got error - because I types TractSeg instead of Tracking! TractSeg: error: unrecognized arguments: --tracking_format tck --> issue explained in https://github.com/MIC-DKFZ/TractSeg/issues/36

```

### Fiber track visualization
[Fiber tract visualised on a glass brain - General Discussion - MRtrix3 Community](https://community.mrtrix.org/t/fiber-tract-visualised-on-a-glass-brain/4932)



```shell
#mrresize mask.mif -scale 5 mask_up.mif mrfilter mask_up.mif smooth -stdev 2 
mrgrid mask.mif regrid -scale 5 mask_up.mif
mask_smooth.mif mrthreshold mask_smooth.mif -abs 0.5 mask_thres.mif maskfilter mask_thres.mif dilate -npass 2 mask_dilated.mif mrcalc mask_dilated.mif mask_thres.mif -subtract glass_brain.mif

```


### Extracting Fixel based measures from TractSeg

https://community.mrtrix.org/t/extracting-fd-fc-and-fdc-using-tractseg/7790

Then try `sh2peaks ${template_fod} Template_peaks.nii.gz` , and feed `Template_peaks.nii.gz` as an input into TractSeg. This will generate TractSeg outputs based on the Population Template FOD.

TractSeg will produce track files (.tck), and these can be converted to fixels using [tck2fixel](https://mrtrix.readthedocs.io/en/dev/reference/commands/tck2fixel.html) (for example,  `tck2fixel $TractSeg_region_tck $fixel_directory_in $fixel_masks_dir $Region_fixel_mask`).

The `$Region_fixel_mask` can be used as an input to the `-mask` option when calling the command `fixelcfestats` (which is essentially saying to conduct the statistical analysis, but only in the region ecompassed by the fixel mask).

```Shell

for_each * :tck2fixel $TractSeg_region_tck/IN.tck $fixel_directory_in $fixel_masks_dir $Region_fixel_mask/IN.mif

#working version (run from inside TOM_trakings folder where the tracks are)
for_each *.tck : tck2fixel IN fixel_output fixel_mask_dir PRE.mif

# run from inside the fixel_mask_dir - thresholded versions will be in a folder named thresholded_fixel_mask

for_each *.mif : mrthreshold -abs 0.5 IN thresholded_fixel_masks/PRE_thresholded.mif

for_each *.mif : mrcalc IN PRE_thresholded.mif -multi fixel_mask/PRE_fixel_mask.mif




````

```shell
tck2fixel AF_left.tck fixel_folder_MNI fixel_mask_dir region_fixel_mask.mif
mrview wmfod_template_MNI.mif -fixel fixel_mask_dir/index.mif
mrview wmfod_template_MNI.mif -fixel fixel_mask_dir/region_fixel_mask.mif 

mrthreshold -abs 0.5 fixel_mask_dir/region_fixel_mask.mif - | mrcalc fixel_mask_dir/region_fixel_mask.mif  - -mult fixel_thresholded.mif
```




```

fixelcfestats

For instance, you could even still compute the fixel-fixel connectivity matrix and perform data smoothing using all fixels, and only at the very final `fixelcfestats` step do you constrain statistical inference to only your tract of interest. https://community.mrtrix.org/t/fixel-based-analyses-in-given-tract/5390/8
```

```shell
fixelcfestats -mask  fd_smooth/ files.txt design_matrix.txt contrast_matrix.txt matrix/ stats_fd_AF_left/

fixelcfestats log_fc_smooth/ files.txt design_matrix.txt contrast_matrix.txt matrix/ stats_log_fc/
fixelcfestats fdc_smooth/ files.txt design_matrix.txt contrast_matrix.txt matrix/ stats_fdc/
```


```
tck2fixel tract.tck fixel_directory fixel_directory/mask.nii.gz

mrview template.nii.gz -fixel fixel_directory mask.nii.gz

#### **Explanation of the command:**

- **`tract.tck`** → Your tract file (e.g., from `tckgen` or TractSeg output).
- **`fixel_directory`** → A directory where fixel data will be stored (this should exist or be created).
- **`fixel_directory/mask.nii.gz`** → The output **fixel mask**, which contains the fixels corresponding to the streamlines.


```Shell

for_each * : tck2fixel IN.tck IN/fod_in_template_space_NOT_REORIENTED.mif IN/fixel_in_template_space_NOT_REORIENTED -afd fd.mif

```


## Statistics

## **1. Combine Tractograms Across Hemispheres**

```shell

tckedit tractseg_output/CST_left.tck tractseg_output/CST_right.tck tract_files/CST.tck

- Merges the left and right CST tractograms into a single file.
```

## **2. Convert Tractograms to TDI Maps**

```shell

tck2fixel tract_files/CST.tck fixel_mask tract_TDIs/CST/ TDI.mif

- Converts tractograms into a fixel-based TDI map.
- Ensure `fixel_mask` exists and corresponds to the whole-brain fixel template.

```

## **3. Crop Whole-Brain Fixel Maps to CST-Specific Fixels**

```shell

fixelcrop fd tract_TDIs/CST/TDI.mif tract_fixels/fd/CST

- Extracts fixels only within the CST from whole-brain fixel-wise fiber density (FD) maps.

```
## **4. Compute Fixel-Wise Statistics Using CFE**

### **4.1 Create the Fixel Connectivity Matrix**

```shell
fixelconnectivity tract_fixels/fd/CST tract_files/CST.tck matrix/CST

- Constructs a fixel connectivity matrix to enable statistical inference.
```

### **4.2 Smooth the Fixel Data**

```shell

fixelfilter tract_fixels/fd/CST smooth tract_fixels_smoothed/fd/CST -matrix matrix/CST

- Applies spatial smoothing to improve statistical power.

```
### **4.3 Perform Statistical Analysis**

```shell

fixelcfestats tract_fixels_smoothed/fd/CST files.txt design_matrix.txt contrast_matrix.txt matrix/CST tract_stats/fd/CST

- Runs statistical analysis to identify significant group differences in FD.
- Ensure `files.txt` lists subject-specific fixel metric files.
- `design_matrix.txt` includes covariates (e.g., age, sex, motion).
- `contrast_matrix.txt` defines the statistical test (e.g., ADHD vs. control).

```

## **5. Thresholding Significant Fixels**

```shell

mrthreshold tract_stats/fd/CST/fwe_1mpvalue.mif -abs 0.95 tract_stats/fd/CST/sig_fixels_05.mif

- Retains only fixels with FWE-corrected p-values **< 0.05**.

```

```shell
#Running within template/tracts_fixel/fd/CST_left
for_each *.mif : echo -n NAME ,  '>>' mean_CST_right.txt "&&" mrstats IN -output mean '>>' mean_CST_right.txt

for_each *.mif : echo -n NAME ,  '>>' mean_CST_right.txt "&&" mrstats IN -mask tracts_stats/fd/CST_right/sig_fixels_05.mif-output mean '>>' mean_CST_right_sig_05.txt

```

```
## **6. Extract Average FD Across Significant Fixels**

```shell
mrstats tract_fixels/fd/CST/subject_ID.mif -mask tract_stats/fd/CST/sig_fixels_05.mif -output mean

- Computes the mean FD value for each subject within significant fixels.
- Use these values for box plots.

```
## **7. Correlation of FD with ADHD Severity**

- Select fixels with **pFWE < 0.05** and correlate with **Conners-3 ADHD Index** scores.
- Similar to step **4**, rerun `fixelcfestats` using **Conners-3 scores** as the independent variable in the design matrix.



June 6th 2025

# Using FixelCrop function

# 📦 Example directory structure:

  `├── thresholded_fixel_masks/`
  `│     ├── ATR_left_thresholded.mif`
  `│     └── ILF_right_thresholded.mif`
  `└── tracts_fixel_smoothed/`
        `└── fd/`
             `├── ATR_left/`
             `│     └── NF225_1.mif`
             `└── ILF_right/`
                   `└── NF225_1.mif`
## crop all `.mif` files in each tract directory using that tract's mask.

``` shell
#!/bin/bash
exec > >(tee -a "run_log.txt") 2>&1
echo "---- Script started on $(date) ----"

# load mrtrix for fixelcrop to work
module load mrtrix

# Specify the directory containing the folders
# TOM_trackings_dir="/home/weerathh/Downloads/TractSeg_analysis/tractseg_output/TOM_trackings"
# population_template_dir="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template"
# TDI_dir="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template/tracts_TDIs"
fixel_dir="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template/tracts_fixel"
# tracts_dir="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template/tracts_files"
# stats_dir="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template/tracts_stats"
smoothed_dir="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template/tracts_fixel_smoothed"
# profile_dir="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template/tracts_profile"
thresholded_tract_masks_dir="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template/thresholded_fixel_masks"

# Define the folders used for the analysis
output_dir="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template/thresholded_fixel_masks_cropped"

# Defining Variables - Tracts from folder lists
tracts=()

# Populate tracts[] with tract names (folders)
for mask_folder in ${thresholded_tract_masks_dir}/*; do
  
  foldername=$(basename "$mask_folder")
  tract="${foldername}"
  tracts+=("$tract")
  #echo "Processing file: $tract"
done

mkdir -p "$output_dir"

for tract in $(ls $mask_dir/*_thresholded.mif); do
  tract_name=$(basename "$tract" _thresholded.mif)
  echo "Processing file: $tract_name"
  mkdir -p ${output_dir}/${tract_name}
  
  for fixel_file in ${tract_dir}/*.mif; do
    filename=$(basename "$fixel_file")
    echo "Processing fixel file: $filename"
    #fixelcrop "$fixel_file" "$tract" ${output_dir}/${tract_name}/$filename
  done
done
```



## split_thresholded_masks.sh

```Shell

#!/bin/bash

# Set input and output directories
input_dir="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template/thresholded_fixel_masks"
output_dir="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template/thresholded_fixel_masks_folders"

# Make output directory if it doesn't exist
mkdir -p "$output_dir"

# Loop over all *_thresholded.mif files
for mask_file in "${input_dir}"/*_thresholded.mif; do
  # Extract tract name (e.g., AF_left)
  filename=$(basename "$mask_file")
  tract_name="${filename%_thresholded.mif}"

  # Create output subfolder for this tract
  tract_dir="${output_dir}/${tract_name}"
  mkdir -p "$tract_dir"

  # Copy the mask, index, and directions files
  cp "$mask_file" "${tract_dir}/"
  cp "${input_dir}/index.mif" "${tract_dir}/"
  cp "${input_dir}/directions.mif" "${tract_dir}/"

  echo "Copied ${tract_name}_thresholded.mif to ${tract_dir}/ with index.mif and directions.mif"
done

```


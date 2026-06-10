# Group fixel-based analysis

Once the initial preprocessing steps are done

4. Computing (average) tissue response functions
	1. First generate individual response functions
	    batch_fixel_script1.sh
```Shell
for_each * : dwi2response dhollander IN/dwi.mif IN/response_wm.txt IN/response_gm.txt IN/response_csf.txt
```

	2. Then generate the response mean consolidating all
		batch_fixel_scrip2.sh
```Shell
responsemean */response_wm.txt ../group_average_response_wm.txt
responsemean */response_gm.txt ../group_average_response_gm.txt
responsemean */response_csf.txt ../group_average_response_csf.txt
```
	
5. Up sampling DW images
```Shell 
for_each * : mrgrid IN/dwi.mif regrid -vox 1.25 IN/dwi_upsampled.mif
```
	
6. Compute up sampled brain mask images
```Shell
for_each * : dwi2mask IN/dwi_upsampled.mif IN/dwi_mask_upsampled.mif
```

> QA1
> * Check all individual participant masks to see if all regions of the brain are included 
> - FOD will only be generated for included regions 
> - later for template space , if one individual mask excludes a specific region, it will remove that region from the entire analysis 
> - therefore better include more than less 
> - bias correction may remove regions of the mask - beware

7. Fiber orientation distribution estimation
```
for_each * : dwi2fod msmt_csd IN/dwi_upsampled.mif ../group_average_response_wm.txt IN/wmfod.mif ../group_average_response_gm.txt IN/gm.mif  ../group_average_response_csf.txt IN/csf.mif -mask IN/dwi_mask_upsampled.mif
```

8. Joint bias field correction and intensity normalization
```Shell
for_each * : mtnormalise IN/wmfod.mif IN/wmfod_norm.mif IN/gm.mif IN/gm_norm.mif IN/csf.mif IN/csf_norm.mif -mask IN/dwi_mask_upsampled.mif
```

> QA2
> * Here is is important to be conservative in the masks selected, as non-brian voxels can generate issues in this step.

9. Generate a study-specific unbiased FOD template
	1. Select a subset of participants n = 20 from each group (CT,CWS)
	2. Make template directory  and input all FOD inputs and corresponding mask images of those participants 
	3. symbolic link all FOD images (and masks) into a single input folder
	4.  run the template building script
```Shell
#mkdir -p ../template/fod_input
#mkdir ../template/mask_input

for_each `ls -d SF[0-9][0-9][0-9]_1 |sort -g | tail -10` : ln -sr IN/wmfod_norm.mif ../template/fod_input/PRE.mif ";" ln -sr IN/dwi_mask_upsampled.mif ../template/mask_input/PRE.mif

for_each `ls -d SM[0-9][0-9][0-9]_1 |sort -g | tail -10` : ln -sr IN/wmfod_norm.mif ../template/fod_input/PRE.mif ";" ln -sr IN/dwi_mask_upsampled.mif ../template/mask_input/PRE.mif

for_each `ls -d NF[0-9][0-9][0-9]_1 |sort -g | tail -10` : ln -sr IN/wmfod_norm.mif ../template/fod_input/PRE.mif ";" ln -sr IN/dwi_mask_upsampled.mif ../template/mask_input/PRE.mif

for_each `ls -d NM[0-9][0-9][0-9]_1 |sort -g | tail -10` : ln -sr IN/wmfod_norm.mif ../template/fod_input/PRE.mif ";" ln -sr IN/dwi_mask_upsampled.mif ../template/mask_input/PRE.mif

# to use the full population
for_each * : ln -sr IN/wmfod_norm.mif ../template/fod_input/PRE.mif
for_each * : ln -sr IN/dwi_mask_upsampled.mif ../template/mask_input/PRE.mif

population_template ../template/fod_input -mask_dir ../template/mask_input ../template/wmfod_template.mif -voxel_size 1.25

```

10. Register all subject FOD images to the FOD template
```Shell
for_each * : mrregister IN/wmfod_norm.mif -mask1 IN/dwi_mask_upsampled.mif ../template/wmfod_template.mif -nl_warp IN/subject2template_warp.mif IN/template2subject_warp.mif
```

11. Compute the template mask
```Shell
for_each * : mrtransform IN/dwi_mask_upsampled.mif -warp IN/subject2template_warp.mif -interp nearest -datatype bit IN/dwi_mask_in_template_space.mif

mrmath */dwi_mask_in_template_space.mif min ../template/template_mask.mif -datatype bit

```

> QA3
> * Check the resulting template mask includes all regions of the brain intended to be analyzed 
> * Might have to retrace previous steps to correct it if not

12. Computer a white matter template analysis fixel mask
	1. Segment fixels from FOD template

```Shel
fod2fixel -mask ../template/template_mask.mif -fmls_peak_value 0.06 ../template/wmfod_template.mif ../template/fixel_mask

```

 QA4
> * Visualize output of fixel mask `../template/fixel_mask/index.mif` using `mrview` fixel plot tool
> * mrinfo -size ../template/fixel_mask/directions.mif several hundreds of thousands of fixels expected for adult brain

13. Warp FOD images to template space
```Shell
for_each * : mrtransform IN/wmfod_norm.mif -warp IN/subject2template_warp.mif -reorient_fod no IN/fod_in_template_space_NOT_REORIENTED.mif
```

14. Segment FOD images to estimate fixels and their apparent fibre density (FD)
```Shell
for_each * : fod2fixel -mask ../template/template_mask.mif IN/fod_in_template_space_NOT_REORIENTED.mif IN/fixel_in_template_space_NOT_REORIENTED -afd fd.mif

```

15. Reorient fixels
```
for_each * : fixelreorient IN/fixel_in_template_space_NOT_REORIENTED IN/subject2template_warp.mif IN/fixel_in_template_space
```

16. Assign subject fixels to template fixels (cannot parallalize this step)
```Shell
for_each * : fixelcorrespondence IN/fixel_in_template_space/fd.mif ../template/fixel_mask ../template/fd PRE.mif
```

17. Compute the fibre cross-section (FC) metric
```Shell
for_each * : warp2metric IN/subject2template_warp.mif -fc ../template/fixel_mask ../template/fc IN.mif

mkdir ../template/log_fc
cp ../template/fc/index.mif ../template/fc/directions.mif ../template/log_fc
for_each * : mrcalc ../template/fc/IN.mif -log ../template/log_fc/IN.mif
```

18.  Computer a combined measure of fibre density and cross-section (FDC)
```Shell
mkdir ../template/fdc
cp ../template/fc/index.mif ../template/fdc
cp ../template/fc/directions.mif ../template/fdc
for_each * : mrcalc ../template/fd/IN.mif ../template/fc/IN.mif -mult ../template/fdc/IN.mif
```

19. Perform whole-brain fibre tractography on the FOD template
```Shell
cd ../template
tckgen -angle 22.5 -maxlen 250 -minlen 10 -power 1.0 wmfod_template.mif -seed_image template_mask.mif -mask template_mask.mif -select 20000000 -cutoff 0.06 tracks_20_million.tck
```

[[slight deviation here - I need to generate ROI based tractography for seed masks]]



20. Reduce biases in tractogram densities
```Shell
tcksift tracks_20_million.tck wmfod_template.mif tracks_2_million_sift.tck -term_number 2000000
```

21. Generate fixel-fixel connectivity matrix (WARNING - need a lot of memory space!)
```
fixelconnectivity fixel_mask/ tracks_2_million_sift.tck matrix/
```

22. Smooth fixe data using fixel-fixel connectivity
```Shell
fixelfilter fd smooth fd_smooth -matrix matrix/
fixelfilter log_fc smooth log_fc_smooth -matrix matrix/
fixelfilter fdc smooth fdc_smooth -matrix matrix/
```

23. Perform statistical analysis of FD, FC, and FDC
The input `files.txt` is a text file containing the filename of each file (i.e. _not_ the full path) to be analysed inside the input fixel directory, each filename on a separate line. The line ordering should correspond to the lines in the file `design_matrix.txt`
```Shell
fixelcfestats fd_smooth/ files.txt design_matrix.txt contrast_matrix.txt matrix/ stats_fd/
fixelcfestats log_fc_smooth/ files.txt design_matrix.txt contrast_matrix.txt matrix/ stats_log_fc/
fixelcfestats fdc_smooth/ files.txt design_matrix.txt contrast_matrix.txt matrix/ stats_fdc/
```

24. Visualize the results
```
mrview <FOD template image> -overlay.load <fixel images> 
mrview fixel plot tool 1-p-value --> threshold of p < 0.05 and lower threshold of 0.95
```


## Running batch scripts on Great lakes cluster

Subjlist.txt generation 

```Shell
cd $subjects_folder
ls -d */ | sed 's|/$||' > ../subjlist.txt
```

https://andysbrainbook.readthedocs.io/en/latest/MRtrix/MRtrix_Course/MRtrix_11_FixelBasedAnalysis.html





## Generating spherical ROIs

#### To create a spherical ROI:

1. Create images of coordinates (one image for x, y, z – using [multi-file syntax 5](https://mrtrix.readthedocs.io/en/latest/getting_started/image_data.html#multi-file-numbered-image-support)):
    
    `warpinit teamplate.mif pos-[].mif`
    
2. Set location and radius of sphere (using BASH variables):
    
    `x=0 y=10 z=-5 r=20`
    
3. Compute ROI using [mrcalc 8](https://mrtrix.readthedocs.io/en/3.0_rc3/reference/commands/mrcalc.html) (note stack-based syntax – not pretty, but very effective):
```shell

mrcalc pos-0.mif $x -sub 2 -pow pos-1.mif $y -sub 2 -pow pos-2.mif $z -sub 2 -pow -add -add $r 2 -pow -lt roi.mif
mrcalc: [100%] computing: (((pos-0.mif - 0)^2 + ((pos-1.mif - 10)^2 + (pos-2.mif - -5)^2)) < 400)

```

### Converting group template to MNI space

```shell


mrconvert wmfod_template.mif wmfod_template.nii.gz
mrconvert wmfod_template.nii.gz I0image.nii.gz -coord 3 0

flirt -in I0image.nii.gz -ref MNI152_T1_2mm.nii.gz -out I0image_MNI.nii.gz -omat wmfod_template_2_MNI.mat -dof 12

transformconvert wmfod_template_2_MNI.mat I0image.nii.gz MNI152_T1_2mm.nii.gz
flirt_import wmfod_template_2_MNI.txt

mrtransform wmfod_template.nii.gz -linear wmfod_template_2_MNI.txt -template MNI152_T1_2mm.nii.gz wmfod_template_MNI.nii.gz

mrconvert wmfod_template_MNI.nii.gz wmfod_template_MNI.mif

```



### Using HCP MNI FOD to transform FOD_template
https://community.mrtrix.org/t/warping-fod-and-tck-files-to-mni-template/2049

https://github.com/MIC-DKFZ/TractSeg/issues/167 
1. Registering the wm_fod file to MNI space would be possible with the mrtrix fod registration commands and an HCP fod image as target (as HCP is in MNI space, this will be sufficient. If you need a HCP image you can check the Diffusion.nii.gz image here: [https://github.com/MIC-DKFZ/TractSeg/tree/master/examples](https://github.com/MIC-DKFZ/TractSeg/tree/master/examples)) . But you could also register the DWI images to MNI space first and then do all the processing.


Converted the Diffusion image given at example to a FOD (wmfod_MNI.mif) using the CSD pipeline.
```shell
************************************************
Image:               "wmfod_MNI.mif"
************************************************
  Dimensions:        73 x 87 x 73 x 45
  Voxel size:        2.5 x 2.5 x 2.5 x 1
  Data strides:      [ -2 3 4 1 ]
  Format:            MRtrix
  Data type:         32 bit float (little endian)
  Intensity scaling: offset = 0, multiplier = 1
  Transform:                    1          -0          -0         -90
                               -0           1          -0        -126
                                0           0           1         -72
  SS3T-CSD_bzero_pct: 10.0
  SS3T-CSD_niter:    3
  SS3T-CSD_sdm_csf:  2.8744143190907097
  SS3T-CSD_sdm_gm:   0.8085713666295767
  SS3T-CSD_sdm_sfwm: 0.6049269537778732
  command_history:   mrconvert Diffusion.nii.gz Diffusion.mif -fslgrad Diffusion.bvecs Diffusion.bvals -force  (version=3.0.4)
                     /app/apps/rhel8/mrtrix/tissue/bin/ss3t_csd_beta1 Diffusion.mif wm.txt wmfod.mif gm.txt gmfod.mif csf.txt csffod.mif -mask mask.mif  (version=3Tissue_v5.2.9)"
  mrtrix_version:    3Tissue_v5.2.9
  prior_dw_scheme:   0.0,0.0,0.0,0.0
  [33 entries]       0.9099680494,0.3162830172,0.2681850146,999.998
                     ...
                     -0.3523978971,-0.9323707278,-0.08062597646,1000.0
                     0.0555450117,-0.2701660569,0.9612102025,1000.0

```


I might need to reorient this but currently it is in the orientation I use.
I might have to resample this too. But let's see if it works without first.

```Shell
mrinfo wmfod_template.mif 
************************************************
Image:               "wmfod_template.mif"
************************************************
  Dimensions:        140 x 174 x 125 x 45
  Voxel size:        1.25 x 1.25 x 1.25 x 12.8
  Data strides:      [ -2 3 4 1 ]
  Format:            MRtrix
  Data type:         32 bit float (little endian)
  Intensity scaling: offset = 0, multiplier = 1
  Transform:                    1           0           0      -81.29
                                0           1           0      -79.61
                                0           0           1      -61.51
  command_history:   /app/apps/rhel8/mrtrix/3.0.4/bin/population_template ../template/fod_input -mask_dir ../template/mask_input ../template/wmfod_template.mif -voxel_size 1.25 -nthreads 64 -nocleanup  (version=3.0.4)
  mrtrix_version:    3.0.4

```


```shell

mrregister wmfod_template.mif wmfod_MNI.mif -type affine -affine FOD_to_MNI_affine.txt
mrtransform wmfod_template.mif wmfod_template_MNI.mif -linear FOD_to_MNI_affine.txt -reorient_fod yes


```
THIS worked!!!


[[TrackSeg_Workflow]]










/////////////////////////////////////////// This did not work
```shell
mrconvert wmfod_template_reoriented.mif wmfod_template_reoriented.nii.gz  
mrconvert wmfod_template_reoriented.nii.gz I0image_reoriented.nii.gz -coord 3 0  
  
flirt -in I0image_reoriented.nii.gz -ref HCP_MNI_FOD_single.nii.gz -out  I0image_reoriented_MNI.nii.gz -omat wmfod_template_MNIfinal.mat -dof 12

transformconvert wmfod_template_MNIfinal.mat I0image_reoriented.nii.gz HCP_MNI_FOD_single.nii.gz flirt_import wmfod_template_MNIfinal.txt

mrtransform wmfod_template_reoriented.nii.gz -linear wmfod_template_MNIfinal.txt -template HCP_MNI_FOD_single.nii.gz wmfod_template_MNIfinal.nii.gz -reorient_fod yes

mrconvert wmfod_template_MNIfinal.nii.gz wmfod_template_MNIfinal.mif



mrregister wmfod_template_reoriented.mif HCP_MNI_FOD_single.nii.gz  -type affine  -affine_init wmfod_template_MNIfinal.txt  -affine wmfod_template_affine.txt
```


[[Poor Registration with mrregister compared with ANTS]]


https://community.mrtrix.org/t/warping-fod-and-tck-files-to-mni-template/2049 
### Warping FOD and tck files to MNi template

However --> the displacement field provided in the HCP is not quite in the right format for our tools. We expect a _deformation_ field, which stores the x,y,z positions in the target space, rather than the _displacement_ field containing the x,y,z, translations of each voxel. So the first step is to convert the displacement field to a deformation field. This was what the first step in the post you linked to was about:

```shell

warpconvert standard2acpc_dc.nii.gz -type displacement2deformation warp_subj2MNI.nii.gz
```


[[Glass_brain]]


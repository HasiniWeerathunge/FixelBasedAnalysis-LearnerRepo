#!/bin/bash
module load mrtrix
# Specify the directory containing the folders
parent_dir="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/subjects"

cd $parent_dir

### Register all subject FOD images to the FOD template
#for_each -nthreads 48 * : mrregister IN/wmfod_norm.mif -mask1 IN/dwi_mask_upsampled.mif ../template/wmfod_template.mif -nl_warp IN/subject2template_warp.mif IN/template2subject_warp.mif

### Compute the template mask
#for_each -nthreads 48 * : mrtransform IN/dwi_mask_upsampled.mif -warp IN/subject2template_warp.mif -interp nearest -datatype bit IN/dwi_mask_in_template_space.mif

#mrmath */dwi_mask_in_template_space.mif min ../template/template_mask.mif -datatype bit

### Computer a white matter template analysis fixel mask
	#1. Segment fixels from FOD template

#fod2fixel -mask ../template/template_mask.mif -fmls_peak_value 0.06 ../template/wmfod_template.mif ../template/fixel_mask -nthreads 48

### Warp FOD images to template space
#for_each -nthreads 48 * : mrtransform IN/wmfod_norm.mif -warp IN/subject2template_warp.mif -reorient_fod no IN/fod_in_template_space_NOT_REORIENTED.mif -force

## Segment FOD images to estimate fixels and their apparent fibre density (FD)
#for_each -nthreads 48 * : fod2fixel -mask ../template/template_mask.mif IN/fod_in_template_space_NOT_REORIENTED.mif IN/fixel_in_template_space_NOT_REORIENTED -afd fd.mif -force

## Reorient fixels
#for_each -nthreads 48 * : fixelreorient IN/fixel_in_template_space_NOT_REORIENTED IN/subject2template_warp.mif IN/fixel_in_template_space -force

## Assign subject fixels to template fixels
#mkdir ../template/fd
#for_each -nthreads 48 * : fixelcorrespondence IN/fixel_in_template_space/fd.mif ../template/fixel_mask ../template/fd IN.mif 

## Compute the fibre cross-section (FC) metric
#for_each -nthreads 48 * : warp2metric IN/subject2template_warp.mif -fc ../template/fixel_mask ../template/fc IN.mif 

#mkdir ../template/log_fc
#cp ../template/fc/index.mif ../template/fc/directions.mif ../template/log_fc
#for_each -nthreads 48 * : mrcalc ../template/fc/IN.mif -log ../template/log_fc/IN.mif 

## Computer a combined measure of fibre density and cross-section (FDC)
#mkdir ../template/fdc
#cp ../template/fc/index.mif ../template/fdc
#cp ../template/fc/directions.mif ../template/fdc
#for_each -nthreads 48 * : mrcalc ../template/fd/IN.mif ../template/fc/IN.mif -mult ../template/fdc/IN.mif

### Perform whole-brain fibre tractography on the FOD template
cd ../template
#tckgen -angle 22.5 -maxlen 250 -minlen 10 -power 1.0 wmfod_template.mif -seed_image template_mask.mif -mask template_mask.mif -select 20000000 -cutoff 0.06 tracks_20_million.tck -nthreads 48

### Reduce biases in tractogram densities
#tcksift tracks_20_million.tck wmfod_template.mif tracks_1_million_sift.tck -term_number 1000000 -nthreads 48

#tcksift tracks_20_million.tck wmfod_template.mif tracks_2_million_sift.tck -term_number 2000000 -nthreads 48

### Generate fixel-fixel connectivity matrix (WARNING - need a lot of memory space!)
fixelconnectivity fixel_mask/ tracks_2_million_sift.tck matrix/ -nthreads 48

### Smooth fixe data using fixel-fixel connectivity
fixelfilter fd smooth fd_smooth -matrix matrix/ -nthreads 48
fixelfilter log_fc smooth log_fc_smooth -matrix matrix/ -nthreads 48
fixelfilter fdc smooth fdc_smooth -matrix matrix/ -nthreads 48

## Perform statistical analysis of FD, FC, and FDC
##The input `files.txt` is a text file containing the filename of each file (i.e. _not_ the full path) to be analysed inside the input fixel directory, each filename ##on a separate line. The line ordering should correspond to the lines in the file `design_matrix.txt`

#fixelcfestats fd_smooth/ files_v1.txt design_matrix_v2.txt contrast_matrix_v2.txt matrix/ stats_fd_v2/ -nthreads 48
#fixelcfestats log_fc_smooth/ files_v1.txt design_matrix_v2.txt contrast_matrix_v2.txt matrix/ stats_log_fc_v2/ -nthreads 48
#fixelcfestats fdc_smooth/ files_v1.txt design_matrix_v2.txt contrast_matrix_v2.txt matrix/ stats_fdc_v2/ -nthreads 48




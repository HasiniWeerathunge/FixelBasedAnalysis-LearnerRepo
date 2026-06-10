#!/bin/bash
module load mrtrix
# Specify the directory containing the folders
parent_dir="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/subjects"

cd $parent_dir

cd ../template



# for each IFG mask --> extract tracks of interest after SIFT step

#tckedit tracks_1_million_sift.tck -include mask_Left_Cluster1_templatespace.mif tracks_1_million_sift_left_cluster1.tck -nthreads 16

#tckedit tracks_1_million_sift.tck -include mask_Left_Cluster2_templatespace.mif tracks_1_million_sift_left_cluster2.tck -nthreads 16

#tckedit tracks_1_million_sift.tck -include mask_Left_Cluster3_templatespace.mif tracks_1_million_sift_left_cluster3.tck -nthreads 16

#tckedit tracks_1_million_sift.tck -include mask_Left_Cluster4_templatespace.mif tracks_1_million_sift_left_cluster4.tck -nthreads 16

#tckedit tracks_1_million_sift.tck -include mask_Left_Cluster5_templatespace.mif tracks_1_million_sift_left_cluster5.tck -nthreads 16

#tckedit tracks_1_million_sift.tck -include mask_Right_Cluster1_templatespace.mif tracks_1_million_sift_right_cluster1.tck -nthreads 16

#tckedit tracks_1_million_sift.tck -include mask_Right_Cluster2_templatespace.mif tracks_1_million_sift_right_cluster2.tck -nthreads 16

#tckedit tracks_1_million_sift.tck -include mask_Right_Cluster3_templatespace.mif tracks_1_million_sift_right_cluster3.tck -nthreads 16

#tckedit tracks_1_million_sift.tck -include mask_Right_Cluster4_templatespace.mif tracks_1_million_sift_right_cluster4.tck -nthreads 16

#tckedit tracks_1_million_sift.tck -include mask_Right_Cluster5_templatespace.mif tracks_1_million_sift_right_cluster5.tck -nthreads 16


#mrview wmfod_template.mif -tractography.load tracks_1_million_sift_left_cluster1.tck -overlay.load mask_Left_Cluster1_templatespace.mif



# for each IER mask --> extract tracks of interest after SIFT step


#tckedit tracks_1_million_sift.tck -include roi_il_templatespace.mif tracks_1_million_sift_il.tck -nthreads 16

#mrview wmfod_template.mif -tractography.load tracks_1_million_sift_il.tck -overlay.load roi_il_templatespace.mif -overlay.colourmap 2 


tckedit tracks_1_million_sift.tck -include roi_il_templatespace.mif tracks_1_million_sift_il.tck -nthreads 16


mrview wmfod_template.mif -tractography.load smallerTracks_200k_left_cluster1.tck -overlay.load mask_Left_Cluster1_templatespace.mif -overlay.colourmap 2 





#mrview wmfod_template.mif -tractography.load  smallerTracks_200k_left_cluster1.tck


## Generate fixel-fixel connectivity matrix (WARNING - need a lot of memory space!)
#fixelconnectivity fixel_mask/ tracks_2_million_sift.tck matrix/

## Smooth fixe data using fixel-fixel connectivity
#fixelfilter fd smooth fd_smooth -matrix matrix/
#fixelfilter log_fc smooth log_fc_smooth -matrix matrix/
#fixelfilter fdc smooth fdc_smooth -matrix matrix/

## Perform statistical analysis of FD, FC, and FDC
##The input `files.txt` is a text file containing the filename of each file (i.e. _not_ the full path) to be analysed inside the input fixel directory, each filename ##on a separate line. The line ordering should correspond to the lines in the file `design_matrix.txt`

#fixelcfestats fd_smooth/ files.txt design_matrix.txt contrast_matrix.txt matrix/ stats_fd/
#fixelcfestats log_fc_smooth/ files.txt design_matrix.txt contrast_matrix.txt matrix/ stats_log_fc/
#fixelcfestats fdc_smooth/ files.txt design_matrix.txt contrast_matrix.txt matrix/ stats_fdc/ -nthreads 16


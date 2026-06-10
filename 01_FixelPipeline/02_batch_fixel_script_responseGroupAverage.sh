#!/bin/bash

module load mrtrix
# Specify the directory containing the folders
parent_dir="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/subjects"

cd $parent_dir
# Loop through each folder in the parent directory

responsemean */response_wm.txt ../group_average_response_wm_cohort2.txt
responsemean */response_gm.txt ../group_average_response_gm_cohort2.txt
responsemean */response_csf.txt ../group_average_response_csf_cohort2.txt

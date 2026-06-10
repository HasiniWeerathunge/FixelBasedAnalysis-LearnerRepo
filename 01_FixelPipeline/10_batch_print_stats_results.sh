#!/bin/bash

## Specify the directory containing the folders
parent_di1="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template/fd_withoutindex"
parent_di2="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template/fdc_withoutindex"
parent_di3="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template/log_fc_withoutindex"

parent_di4="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template/fd_smooth_withoutindex"
parent_di5="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template/fdc_smooth_withoutindex"
parent_di6="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template/log_fc_smooth_withoutindex"

## Specify output path

filepat1=../RC1_fd_stats.txt
filepat2=../RC1_fdc_stats.txt
filepat3=../RC1_logfc_stats.txt

filepat4=../RC1_fdsmooth_stats.txt
filepat5=../RC1_fdcsmooth_stats.txt
filepat6=../RC1_logfcsmooth_stats.txt

cd $parent_di1
# Loop through each file in the parent directory
for file in "$parent_di1"/*; do

	MEAN=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output mean`
	MEDIAN=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output median`
	STD=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output std`
	STD_RV=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output std_rv`
	MIN=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output min`
	MAX=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output max`
	COUNT=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output count`
        
        echo -n "$(basename "$file")" >> "$filepat1"
 	echo -n " :mean=$MEAN" >> "$filepat1"
	echo -n " :median=$MEDIAN" >> "$filepat1"
        echo -n " :std=$STD" >> "$filepat1"
	echo -n " :std_rv=$STD_RV" >> "$filepat1"
	echo -n " :min=$MIN" >> "$filepat1"
        echo -n " :max=$MAX" >> "$filepat1"
	echo -n " :count=$COUNT" >> "$filepat1"


done



cd $parent_di2
# Loop through each file in the parent directory
for file in "$parent_di2"/*; do

	MEAN=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output mean`
	MEDIAN=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output median`
	STD=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output std`
	STD_RV=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output std_rv`
	MIN=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output min`
	MAX=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output max`
	COUNT=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output count`
        
        echo -n "$(basename "$file")" >> "$filepat2"
 	echo -n " :mean=$MEAN" >> "$filepat2"
	echo -n " :median=$MEDIAN" >> "$filepat2"
        echo -n " :std=$STD" >> "$filepat2"
	echo -n " :std_rv=$STD_RV" >> "$filepat2"
	echo -n " :min=$MIN" >> "$filepat2"
        echo -n " :max=$MAX" >> "$filepat2"
	echo -n " :count=$COUNT" >> "$filepat2"


done




cd $parent_di3
# Loop through each file in the parent directory
for file in "$parent_di3"/*; do

	MEAN=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output mean`
	MEDIAN=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output median`
	STD=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output std`
	STD_RV=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output std_rv`
	MIN=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output min`
	MAX=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output max`
	COUNT=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output count`
        
        echo -n "$(basename "$file")" >> "$filepat3"
 	echo -n " :mean=$MEAN" >> "$filepat3"
	echo -n " :median=$MEDIAN" >> "$filepat3"
        echo -n " :std=$STD" >> "$filepat3"
	echo -n " :std_rv=$STD_RV" >> "$filepat3"
	echo -n " :min=$MIN" >> "$filepat3"
        echo -n " :max=$MAX" >> "$filepat3"
	echo -n " :count=$COUNT" >> "$filepat3"


done




cd $parent_di4
# Loop through each file in the parent directory
for file in "$parent_di4"/*; do

	MEAN=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output mean`
	MEDIAN=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output median`
	STD=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output std`
	STD_RV=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output std_rv`
	MIN=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output min`
	MAX=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output max`
	COUNT=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output count`
        
        echo -n "$(basename "$file")" >> "$filepat4"
 	echo -n " :mean=$MEAN" >> "$filepat4"
	echo -n " :median=$MEDIAN" >> "$filepat4"
        echo -n " :std=$STD" >> "$filepat4"
	echo -n " :std_rv=$STD_RV" >> "$filepat4"
	echo -n " :min=$MIN" >> "$filepat4"
        echo -n " :max=$MAX" >> "$filepat4"
	echo -n " :count=$COUNT" >> "$filepat4"


done



cd $parent_di5
# Loop through each file in the parent directory
for file in "$parent_di5"/*; do

	MEAN=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output mean`
	MEDIAN=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output median`
	STD=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output std`
	STD_RV=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output std_rv`
	MIN=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output min`
	MAX=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output max`
	COUNT=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output count`
        
        echo -n "$(basename "$file")" >> "$filepat5"
 	echo -n " :mean=$MEAN" >> "$filepat5"
	echo -n " :median=$MEDIAN" >> "$filepat5"
        echo -n " :std=$STD" >> "$filepat5"
	echo -n " :std_rv=$STD_RV" >> "$filepat5"
	echo -n " :min=$MIN" >> "$filepat5"
        echo -n " :max=$MAX" >> "$filepat5"
	echo -n " :count=$COUNT" >> "$filepat5"


done


cd $parent_di6
# Loop through each file in the parent directory
for file in "$parent_di6"/*; do

	MEAN=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output mean`
	MEDIAN=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output median`
	STD=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output std`
	STD_RV=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output std_rv`
	MIN=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output min`
	MAX=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output max`
	COUNT=`mrstats -mask ../fixel_mask_output_RC1/fixel_mask_RC1_binary_mask_0_1.mif $file -output count`
        
        echo -n "$(basename "$file")" >> "$filepat6"
 	echo -n " :mean=$MEAN" >> "$filepat6"
	echo -n " :median=$MEDIAN" >> "$filepat6"
        echo -n " :std=$STD" >> "$filepat6"
	echo -n " :std_rv=$STD_RV" >> "$filepat6"
	echo -n " :min=$MIN" >> "$filepat6"
        echo -n " :max=$MAX" >> "$filepat6"
	echo -n " :count=$COUNT" >> "$filepat6"


done








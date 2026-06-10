#!/bin/bash
module load mrtrix
# Specify the directory containing the folders

#cd template_cohort1and2_all

#STATS_DIR="stats_log_fc_centered_Group_positive"
#STATS_DIR="stats_log_fc_centered_Group_negative"

#STATS_DIR="stats_log_fc_centered_Age_positive"
#STATS_DIR="stats_log_fc_centered_Age_negative"

#STATS_DIR="stats_log_fc_centered_Sex_positive"
#STATS_DIR="stats_log_fc_centered_Sex_negative"


STATS_DIR="stats_log_fc_centered_InteractionGroupAge_positive"
#STATS_DIR="stats_log_fc_centered_InteractionGroupAge_negative"


#STATS_DIR="stats_log_fc_centered_InteractionGroupSex_positive"
#STATS_DIR="stats_log_fc_centered_InteractionGroupSex_negative"


    #A. Corrected (PFWE < 0.05) 
    mrthreshold "$STATS_DIR/fwe_1mpvalue.mif" -abs 0.95 "$STATS_DIR/sigmask_FWE_05.mif"
    
    #B. Corrected (PFWE < 0.005)         
    mrthreshold "$STATS_DIR/fwe_1mpvalue.mif" -abs 0.995 "$STATS_DIR/sigmask_FWE_005.mif"   

    #C. Corrected (Puncorrected < 0.001) 
    mrthreshold "$STATS_DIR/uncorrected_pvalue.mif" -abs 0.999 "$STATS_DIR/sigmask_unc_001.mif"


    #D. Corrected (Puncorrected < 0.005) 
    mrthreshold "$STATS_DIR/uncorrected_pvalue.mif" -abs 0.995 "$STATS_DIR/sigmask_unc_005.mif"


    # TSF generation 
    fixel2tsf "$STATS_DIR/sigmask_FWE_05.mif" tracks_20k_sift_LAS.tck "$STATS_DIR/group_effect_FWE_05_20ktracks.tsf"
    fixel2tsf "$STATS_DIR/sigmask_FWE_005.mif" tracks_20k_sift_LAS.tck "$STATS_DIR/group_effect_FWE_005_20ktracks.tsf"
    fixel2tsf "$STATS_DIR/sigmask_unc_001.mif" tracks_20k_sift_LAS.tck "$STATS_DIR/group_effect_unc_001_20ktracks.tsf"
    fixel2tsf "$STATS_DIR/sigmask_unc_005.mif" tracks_20k_sift_LAS.tck "$STATS_DIR/group_effect_unc_005_20ktracks.tsf"


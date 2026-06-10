#!/bin/bash
module load mrtrix

# -----------------------------
# Paths
# -----------------------------
SUBJ_DIR="log_fc_smooth"                           # folder with subject logFC images
#TRACT_DIR="tract_based_analysis/fixel_mask_tracts_selected"  # folder with tract masks
STATS_DIR="stats_log_fc_centered_InteractionGroupAge_negative" #folder with statistical results from fixelcfestats GLMs for each tract
OUT_DIR="SIG_mean_logFC/GroupAgeInteraction_negative"                     # output folder for CSVs
mkdir -p $OUT_DIR

# Combined CSV (long format)
COMBINED_CSV="$OUT_DIR/SIG_mean_logFC_WholeBrain.csv"
echo "Subject,MeanLogFC,MeanLogFC_FWE_05,MeanLogFC_FWE_005,MeanLogFC_unc_001,MeanLogFC_unc_0025,MeanLogFC_unc_005" > $COMBINED_CSV

    #A. Corrected (PFWE < 0.05) 
    mrthreshold "$STATS_DIR/fwe_1mpvalue.mif" -abs 0.95 "$STATS_DIR/sigmask_FWE_05.mif"
    
    #B. Corrected (PFWE < 0.005)         
    mrthreshold "$STATS_DIR/fwe_1mpvalue.mif" -abs 0.995 "$STATS_DIR/sigmask_FWE_005.mif"   

    #C. Corrected (Puncorrected < 0.001) 
    mrthreshold "$STATS_DIR/uncorrected_pvalue.mif" -abs 0.999 "$STATS_DIR/sigmask_unc_001.mif"

    #D. Corrected (Puncorrected < 0.0025) 
    mrthreshold "$STATS_DIR/uncorrected_pvalue.mif" -abs 0.9975 "$STATS_DIR/sigmask_unc_0025.mif"

    #D. Corrected (Puncorrected < 0.005) 
    mrthreshold "$STATS_DIR/uncorrected_pvalue.mif" -abs 0.995 "$STATS_DIR/sigmask_unc_005.mif"


    # TSF generation 
    fixel2tsf "$STATS_DIR/sigmask_FWE_05.mif" tracks_20k_sift_LAS.tck "$STATS_DIR/group_effect_FWE_05_20ktracks.tsf"
    fixel2tsf "$STATS_DIR/sigmask_FWE_005.mif" tracks_20k_sift_LAS.tck "$STATS_DIR/group_effect_FWE_005_20ktracks.tsf"
    fixel2tsf "$STATS_DIR/sigmask_unc_001.mif" tracks_20k_sift_LAS.tck "$STATS_DIR/group_effect_unc_001_20ktracks.tsf"
    fixel2tsf "$STATS_DIR/sigmask_unc_0025.mif" tracks_20k_sift_LAS.tck "$STATS_DIR/group_effect_unc_0025_20ktracks.tsf"
    fixel2tsf "$STATS_DIR/sigmask_unc_005.mif" tracks_20k_sift_LAS.tck "$STATS_DIR/group_effect_unc_005_20ktracks.tsf"

    # -----------------------------
    # Loop over subjects (inner loop)
    # -----------------------------
    while read subj; do
	subj_img="$SUBJ_DIR/${subj}"
        #echo $subj_img
        subj_name=$(basename "$subj_img" .mif)
        #echo $subj_name
        if [[ "$subj_name" == "directions" || "$subj_name" == "index" ]]; then
        continue
        fi

        #Create tract-specific significant fixel masks
        
        #A. Corrected (PFWE < 0.05) 
	# Count number of fixels in the significant mask
        num_fixels=$(mrstats "$STATS_DIR/sigmask_FWE_05.mif" -output mean)
        #echo "got to A $subj_name"
        if [[ -z "$num_fixels" ]] || (( $(echo "$num_fixels == 0" | bc -l) )); then
            # No significant fixels → write NA
            meanFC_sig_FWE_05="NA"
        else
            # Compute mean log FC
            meanFC_sig_FWE_05=$(mrstats "$subj_img" -mask "$STATS_DIR/sigmask_FWE_05.mif" -output mean)
        fi
       	

	#B. Corrected (PFWE < 0.005)         
       # Count number of fixels in the significant mask
        num_fixels=$(mrstats "$STATS_DIR/sigmask_FWE_005.mif" -output mean)
        #echo "got to B $subj_name"
        if [[ -z "$num_fixels" ]] || (( $(echo "$num_fixels == 0" | bc -l) )); then
            # No significant fixels → write NA
            meanFC_sig_FWE_005="NA"
        else
            # Compute mean logFC in tract1 using the significant mask
            meanFC_sig_FWE_005=$(mrstats "$subj_img" -mask "$STATS_DIR/sigmask_FWE_005.mif" -output mean)	
        fi
       	    	

        #C. Corrected (Puncorrected < 0.001) 
	# Count number of fixels in the significant mask
        num_fixels=$(mrstats "$STATS_DIR/sigmask_unc_001.mif" -output mean)
        #echo "got to C $subj_name"
        if [[ -z "$num_fixels" ]] || (( $(echo "$num_fixels == 0" | bc -l) )); then
            # No significant fixels → write NA
            meanFC_sig_unc_001="NA"
        else
            # Compute mean logFC in tract1 using the significant mask
       	    meanFC_sig_unc_001=$(mrstats "$subj_img" -mask "$STATS_DIR/sigmask_unc_001.mif" -output mean)	

        fi

        #D. Corrected (Puncorrected < 0.0025) 
	# Count number of fixels in the significant mask
        num_fixels=$(mrstats "$STATS_DIR/sigmask_unc_0025.mif" -output mean)
        #echo "got to D $subj_name"
        if [[ -z "$num_fixels" ]] || (( $(echo "$num_fixels == 0" | bc -l) )); then
            # No significant fixels → write NA
            meanFC_sig_unc_0025="NA"
        else
            # Compute mean logFC in tract1 using the significant mask
       	    meanFC_sig_unc_0025=$(mrstats "$subj_img" -mask "$STATS_DIR/sigmask_unc_0025.mif" -output mean)	

        fi

	#E. Corrected (Puncorrected < 0.005) 
	# mrthreshold "$STATS_DIR/${tract_mask}_fixel_mask/uncorrected_pvalue.mif" -abs 0.995 "$STATS_DIR/${tract_mask}_fixel_mask/sigmask_unc_005.mif"
	# Count number of fixels in the significant mask
        num_fixels=$(mrstats "$STATS_DIR/sigmask_unc_005.mif" -output mean)
        #echo "got to E $subj_name"
        if [[ -z "$num_fixels" ]] || (( $(echo "$num_fixels == 0" | bc -l) )); then
            # No significant fixels → write NA
            meanFC_sig_unc_005="NA"
        else
            # Compute mean logFC in tract1 using the significant mask
       	    meanFC_sig_unc_005=$(mrstats "$subj_img" -mask "$STATS_DIR/sigmask_unc_005.mif" -output mean)	

        fi

     	
	#E. Compute mean logFC in tract mask (all fixels in tract without selecting significance
        meanFC=$(mrstats "$subj_img" -output mean)
        #echo "got to E $subj_name"


	# Combined long-format CSV (columns: Subject, FWE05, FWE005, uncorrected)
	echo "$subj_name,$meanFC,$meanFC_sig_FWE_05,$meanFC_sig_FWE_005,$meanFC_sig_unc_001,$meanFC_sig_unc_0025,$meanFC_sig_unc_005" >> $COMBINED_CSV
	
    done < files_n171_March2026.txt

echo "Mean logFC extraction complete!"
echo "Combined CSV: $COMBINED_CSV"

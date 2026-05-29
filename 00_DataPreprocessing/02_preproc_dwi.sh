#!/bin/bash
# DWI preprocessing: denoising, eddy correction, bias correction
# Usage: ./02_preproc_dwi.sh <input_nifti> <output_dir>

# Example MRtrix preprocessing steps:
dwidenoise "$1" "$2/dwi_denoised.nii.gz"
dwipreproc "$2/dwi_denoised.nii.gz" "$2/dwi_preproc.nii.gz" -rpe_none -pe_dir AP
dwibiascorrect ants "$2/dwi_preproc.nii.gz" "$2/dwi_preproc_biascorr.nii.gz"
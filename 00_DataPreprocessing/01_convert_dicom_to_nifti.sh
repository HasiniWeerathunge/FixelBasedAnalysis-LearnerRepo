#!/bin/bash
# Converts DICOM images to NIfTI format using dcm2niix or MRtrix3
# Usage: ./01_convert_dicom_to_nifti.sh <subject_dicom_dir> <output_nifti_dir>

dcm2niix -z y -f %p_%s -o "$2" "$1"
# OR
# mrconvert "$1" "$2/dwi.nii.gz" -fslgrad ...
# Adapt for specific scanner/output needs.
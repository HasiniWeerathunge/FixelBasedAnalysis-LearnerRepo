#!/bin/bash
# FOD reconstruction step
# Usage: ./04_fod_reconstruction.sh <input_nifti> <output_dir> <wm_response> <gm_response> <csf_response>

dwi2fod msmt_csd "$1" "$3" "$2/wmfod.mif" "$4" "$2/gm.mif" "$5" "$2/csf.mif" -mask "$2/dwi_mask.mif"
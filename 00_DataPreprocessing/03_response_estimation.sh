#!/bin/bash
# Response function estimation for each tissue type
# Usage: ./03_response_estimation.sh <input_nifti> <output_dir>

dwi2response dhollander "$1" "$2/response_wm.txt" "$2/response_gm.txt" "$2/response_csf.txt"
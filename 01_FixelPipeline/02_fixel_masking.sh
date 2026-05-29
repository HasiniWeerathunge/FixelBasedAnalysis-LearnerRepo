#!/bin/bash
# Segment fixels from FOD template, generate template mask
# Usage: ./02_fixel_masking.sh <template> <output_mask_dir>

fod2fixel -mask "$2/template_mask.mif" -fmls_peak_value 0.06 "$1" "$2/fixel_mask"
mrmath "$2/fixel_mask/directions.mif" min "$2/template_mask.mif" -datatype bit
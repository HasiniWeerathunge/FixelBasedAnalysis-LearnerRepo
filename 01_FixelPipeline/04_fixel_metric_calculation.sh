#!/bin/bash
# Calculates FD, FC, FDC metrics in template space
# Usage: ./04_fixel_metric_calculation.sh <fod_in_template> <template_mask> <output_dir>

fod2fixel -mask "$2" "$1" "$3/fixel" -afd fd.mif
warp2metric "$1" -fc "$2" "$3/fc.mif"
mrcalc "$3/fd.mif" "$3/fc.mif" -mult "$3/fdc.mif"
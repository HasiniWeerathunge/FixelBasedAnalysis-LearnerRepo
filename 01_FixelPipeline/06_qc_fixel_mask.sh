#!/bin/bash
# Quick visualization to check fixel mask coverage
# Usage: ./06_qc_fixel_mask.sh <fixel_mask_dir>

mrview "$1/index.mif" --fixel.load "$1/color.mif"
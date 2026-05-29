#!/bin/bash
# Run fixelcfestats with given design/contrast matrices
# Usage: ./05_statistical_analysis.sh <metrics_dir> <files.txt> <design.txt> <contrast.txt> <matrix_dir> <output_dir>

fixelcfestats "$1" "$2" "$3" "$4" "$5" "$6"
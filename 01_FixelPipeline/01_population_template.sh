#!/bin/bash
# Build a population FOD template
# Usage: ./01_population_template.sh <fod_input_folder> <mask_input_folder> <output_template>

population_template "$1" -mask_dir "$2" "$3" -voxel_size 1.25
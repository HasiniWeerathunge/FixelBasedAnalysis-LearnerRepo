#!/bin/bash
# Register subjects’ FODs to study template
# Usage: ./03_registration_to_template.sh <subject_fod> <template> <output_warp> <output_fod_in_template>

mrregister "$1" -mask1 "$2" "$3" -nl_warp "$4" "$5"
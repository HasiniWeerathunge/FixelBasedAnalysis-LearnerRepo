#!/bin/bash
# Master runner for Fixel Pipeline

set -e

bash 01_population_template.sh $@
bash 02_fixel_masking.sh $@
bash 03_registration_to_template.sh $@
bash 04_fixel_metric_calculation.sh $@
bash 05_statistical_analysis.sh $@
bash 06_qc_fixel_mask.sh $@

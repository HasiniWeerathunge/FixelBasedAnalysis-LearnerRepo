# 01_FixelPipeline

This folder contains modular shell scripts for each processing step in the MRtrix fixel-based analysis pipeline.

Each script is named by step order, making it easy to run individually or as part of the master pipeline. See the beginning of each script for usage examples and expected arguments.

- 01_population_template.sh: Builds the group FOD template
- 02_fixel_masking.sh: Segments template fixels and generates mask
- 03_registration_to_template.sh: Registers individual FODs to template space
- 04_fixel_metric_calculation.sh: Calculates fixel metrics (FD, FC, FDC)
- 05_statistical_analysis.sh: Performs statistical tests (fixelcfestats)
- 06_qc_fixel_mask.sh: Quick fixel mask/MRtrix viewer helper
- master_fixel_pipeline.sh: Orchestrates entire pipeline

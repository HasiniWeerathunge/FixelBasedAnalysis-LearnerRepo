# Fixel-Based Analysis Modular Pipeline (Learner Repo)

This repository is a modular and educational reorganization of fixel-based analysis workflows for diffusion MRI (DWI) data.
It is based on HasiniWeerathunge/FixelBasedAnalysis. Here, structure, code, and documentation are optimized for learnability and reproducibility.

## Top-Level Folders
- `00_DataPreprocessing/`: For DWI-to-preprocessed data pipeline (shell scripts, session logs)
- `01_FixelPipeline/`: Scripts and structure for the MRtrix fixel pipeline and batch execution
- `02_StatisticalAnalysis/`: R/fixelfestats shell scripts and model design files
- `03_Visualization/`: All scripts for R-based and shell-based results visualization
- `04_TraitBasedAnalysis/`: ROI, tract, and trait-based post-processing and documentation
- `05_QualityControl/`: QA scripts and logs
- `docs/`: Central teaching documentation
- `templates/`: Templates for subject lists, matrices, and code snippets

See each folder's README for complete details.


---

## Full pipeline diagram

The diagram below covers this folder's steps (1-10) plus how their outputs
feed into `Visualization_and_FigureGeneration/`.

```mermaid
flowchart TD
    A([DWI + brain mask]) --> B["1. Response function<br/>dwi2response per subject"]
    B --> C["2. Group-average response"]
    C --> D["3. Resize mask<br/>upsample to 1.25mm"]
    D --> E["4. 3-Tissue CSD<br/>ss3t_csd_beta1"]
    E --> F["5. Bias correct & normalise<br/>mtnormalise"]
    F --> G([Normalised FODs])

    G --> H["6. Population template"]
    H --> I["7a. Registration & fixel mask"]
    I --> J["7b. FD / FC / FDC metrics"]
    J --> K["7c. Tractography & SIFT"]
    K --> L["7d. Connectivity & smoothing"]
    L --> M["7e. fixelcfestats"]
    M --> N([Significant fixel maps])

    H --> O["9. Generate ROI masks"]
    M --> P["8. Extract ROI tracts"]
    O --> P
    M --> Q["10. Summary statistics"]
    P --> R([Stats tables + tract files])
    Q --> R

    N --> S["Visualization:<br/>masks, tsf, clustering"]
    R --> S
    S --> T["Cluster / tract / whole-brain<br/>mean logFC extraction"]
    T --> U["Tract overlap<br/>with sig. fixels"]
    T --> V([CSV datasets])
    U --> V

    V --> W["Figure generation:<br/>bar / raincloud plots"]
    V --> X["Cluster & tract<br/>scatter plots"]
    V --> Y["Mixed-effects<br/>Age x Group"]
    W --> Z([Final figures & tables])
    X --> Z
    Y --> Z
```

---


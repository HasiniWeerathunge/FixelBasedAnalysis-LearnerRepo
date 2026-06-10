library(dplyr)
library(ggplot2)
library(readxl)

# ----------------------------
# 1. Import data
# ----------------------------
setwd('/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template_cohort1and2_all/mean_logFC_per_tract/')
#df <- read.table("dataset.csv", sep = "\t", header = TRUE, stringsAsFactors = FALSE)
df <- read.csv("dataset.csv", header = TRUE, stringsAsFactors = FALSE)

# ----------------------------
# 2. Tracts
# ----------------------------

# List tract columns
#tract_cols <- c("MeanLogFC_ATRright","MeanLogFC_CC", "MeanLogFC_CSTleft")
tract_cols <- c("MeanLogFC_ATRleft", "MeanLogFC_ATRright","MeanLogFC_CC", "MeanLogFC_CSTleft", "MeanLogFC_CSTright", "MeanLogFC_ILFright" , "MeanLogFC_STRleft", "MeanLogFC_STRright")

tract_labels <- gsub("MeanLogFC_", "", tract_cols)

# ----------------------------
# 3. Covariates for residualization (exclude Age & Group)
# ----------------------------
covariates <- c("Sex", "Site", "TIV_centered", "SES_centered", "VIQ_centered", "MotionMeasure")

# ----------------------------
# 4. Residualize each tract
# ----------------------------
for (tract_col in tract_cols) {
  formula_str <- paste0(tract_col, " ~ ", paste(covariates, collapse = " + "))
  lm_cov <- lm(as.formula(formula_str), data = df)
  df[[paste0(tract_col, "_resid")]] <- resid(lm_cov)
}

# ----------------------------
# 5. Determine consistent y-axis across all tracts
# ----------------------------
resid_cols <- paste0(tract_cols, "_resid")
y_min <- min(df[, resid_cols], na.rm = TRUE)
y_max <- max(df[, resid_cols], na.rm = TRUE)

# Compute the original age from age_centered
mean_age <- mean_age <- 67.41520468
df$age <- df$Age_centered + mean_age

# ----------------------------
# 6. Loop over tracts to generate scatter plots with jitter
# ----------------------------
for (i in seq_along(tract_cols)) {
  
  tract_col <- resid_cols[i]
  tract_name <- tract_labels[i]
  
  df_plot <- df %>%
    select(Group_coded, age, all_of(tract_col)) %>%
    rename(MeanFC_resid = all_of(tract_col))
  
  # Scatter plot with horizontal jitter
  p <- ggplot(df_plot, aes(x = age, y = MeanFC_resid, color = Group_coded)) +
    geom_jitter(width = 0.2, size = 2, alpha = 0.7) +  # add horizontal jitter
    geom_smooth(method = "lm", se = TRUE, aes(fill = Group_coded), alpha = 0.2) +
    scale_color_manual(values = c(
      "Stuttering" = "#A02B93",
      "Control" = "#196B24"
    )) +
    scale_fill_manual(values = c(
      "Stuttering" = "#A02B93",
      "Control" = "#196B24"
    )) +
    ylab("Mean logFC (residualized)") +
    xlab("Age (months)") +
    ggtitle(paste("Group × Age :", tract_name)) +
    #coord_cartesian(ylim = c(y_min, y_max)) +
    theme_minimal(base_size = 14) +
    theme(
      text = element_text(family = "Arial"),
      plot.title = element_text(family = "Arial", face = "bold", hjust = 0.5),
      legend.position = "none",
      panel.grid = element_blank()
    )
  print(p)
  # Save each figure
  ggsave(
   filename = paste0("Scatter_GroupxAge_resid_jitter_", tract_name, ".png"),
    plot = p,
    width = 4,
    height = 4,
    dpi = 300
  )
  
}


covariates <- c("Sex", "Site", "TIV_centered", "SES_centered", "VIQ_centered", "MotionMeasure")
pred_df <- expand.grid(
  age = age_seq,
  Group_coded = levels(df$Group_coded),
  Sex = 0,
  Site = 0,
  TIV_centered = 0,
  SES_centered = 0,
  VIQ_centered = 0,
  Motion_centered = 0
)

# ----------------------------

for(i in seq_along(tract_cols)) {
  
  tract_col <- tract_cols[i]
  tract_name <- tract_labels[i]
  
  # Fit full GLM: Group × Age + covariates
  formula_str <- paste0(tract_col, " ~ Group_coded * age + ", paste(covariates, collapse = " + "))
  lm_full <- lm(as.formula(formula_str), data = df)
  
  # Residualized points for scatter
  df$resid <- resid(lm_full)
  
  # Sequence of ages for smooth lines
  age_seq <- seq(min(df$age), max(df$age), length.out = 100)
  df$Group_coded <- factor(df$Group_coded, levels = c("Control", "Stuttering"))
  # Define prediction dataframe with all covariates included
  pred_df <- expand.grid(
    age = age_seq,
    Group_coded = levels(df$Group_coded),
    Sex = 0,
    Site = 0,
    TIV_centered = 0,
    SES_centered = 0,
    VIQ_centered = 0,
    MotionMeasure = 0
  )
  
  # Now pred_df has 100 rows per group (or 100 * n_groups)
  # Compute predicted GLM values
  pred_df$pred <- predict(lm_full, newdata = pred_df)
  

  # Determine y-axis limits across residuals + predicted values
  y_min <- min(c(df$resid, pred_df$pred), na.rm = TRUE)
  y_max <- max(c(df$resid, pred_df$pred), na.rm = TRUE)
  
  # Plot residualized points with jitter + smooth GLM lines
  ggplot() +
    # residualized scatter points
    geom_jitter(data = df, aes(x = age, y = resid, color = Group_coded),
                width = 0.2, size = 2, alpha = 0.7) +
    # GLM predicted lines
    geom_line(data = pred_df, aes(x = age, y = pred, color = Group_coded), size = 1) +
    scale_color_manual(values = c("Stuttering" = "#A02B93",
                                  "Control" = "#196B24")) +
    ylab("Mean logFC (residualized)") +
    xlab("Age (years)") +
    ggtitle("Group × Age Interaction") +
    theme_minimal(base_size = 14) +
    theme(text = element_text(family = "Arial"),
          panel.grid = element_blank())
  print(p)
  # Save figure per tract
  #ggsave(
  #  filename = paste0("Scatter_GroupxAge_GLM_Smooth_", tract_name, ".png"),
   # plot = p,
  #  width = 4,   # ~2-inch width per panel (adjust if needed)
  #  height = 4,  # adjust if needed for multiple rows
  #  dpi = 300
 # )
  
}
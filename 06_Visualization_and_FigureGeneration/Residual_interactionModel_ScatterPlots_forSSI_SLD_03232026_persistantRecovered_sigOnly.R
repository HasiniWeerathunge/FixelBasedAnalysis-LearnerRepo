library(dplyr)
library(ggplot2)
library(tidyr)

setwd("/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template_cohort1and2_all/SIG_mean_logFC/")

############################################################
# 1. Load demographics
############################################################

demo <- read.csv(
  "mean_logFC_dataset_persistent_recovered.csv",
  stringsAsFactors = FALSE
)

############################################################
# 2. Load fixel data
############################################################

load_direction <- function(folder, direction){
  
  wb <- read.csv(paste0(folder,"/SIG_mean_logFC_WholeBrain.csv"))
  wb$Tract <- "WholeBrain"
  
  tracts <- read.csv(paste0(folder,"/SIG_mean_logFC_all.csv"))
  
  bind_rows(wb, tracts) %>%
    mutate(Direction = direction)
}

#all_data <- load_direction("Group_effect_positive","Positive")
#all_data <- load_direction("Group_effect_negative","Negative")
#all_data <- load_direction("GroupAgeInteraction_positive","Positive")
all_data <- load_direction("GroupAgeInteraction_negative","Negative")
############################################################
# 3. Pivot thresholds
############################################################

all_long <- all_data %>%
  pivot_longer(
    cols = starts_with("MeanLogFC"),
    names_to = "Threshold",
    values_to = "Mean_logFC"
  ) %>%
  mutate(
    Threshold = recode(Threshold,
                       MeanLogFC = "AllFixelMean",
                       MeanLogFC_FWE_05 = "p_FWE<.05",
                       MeanLogFC_FWE_005 = "p_FWE<.005",
                       MeanLogFC_unc_001 = "p_uncorrected<.001",
                       MeanLogFC_unc_0025 = "p_uncorrected<.0025",
                       MeanLogFC_unc_005 = "p_uncorrected<.005"
    )
  )

############################################################
# 4. Merge + clean types
############################################################

data_final <- all_long %>%
  left_join(demo, by = "Subject") %>%
  mutate(
    SSIRater1 = as.numeric(trimws(SSIRater1)),
    
    Age_centered = as.numeric(Age_centered),
    VIQ_centered = as.numeric(VIQ_centered),
    TIV_centered = as.numeric(TIV_centered),
    SES_centered = as.numeric(SES_centered),
    MotionMeasure = as.numeric(MotionMeasure),
    
    Sex = as.factor(Sex),
    Site = as.factor(Site),
    
    Group = case_when(
      Persistent == 1 ~ "Persistent",
      Recovered == 1 ~ "Recovered",
      TRUE ~ NA_character_
    ),
    Group = factor(Group, levels = c("Persistent", "Recovered"))
  ) %>%
  filter(!is.na(Group))

############################################################
# 5. ROI definition (group-only GLM derived)
############################################################

highest_threshold_per_tract <- data_final %>%
  distinct(Tract) %>%
  mutate(
    HighestThreshold = case_when(
      Tract == "WholeBrain" ~ "p_uncorrected<.001",
      TRUE ~ "p_FWE<.05"
    )
  )

plot_data <- data_final %>%
  inner_join(highest_threshold_per_tract, by = "Tract") %>%
  filter(Threshold == HighestThreshold)

valid_tracts <- plot_data %>%
  filter(!is.na(Mean_logFC)) %>%
  pull(Tract) %>%
  unique()

plot_data <- plot_data %>%
  filter(Tract %in% valid_tracts)

############################################################
# 6. Covariates (NO SSI, NO GROUP)
############################################################

covariates <- c(
  "Age_centered", "Sex", "VIQ_centered",
  "TIV_centered", "Site", "SES_centered", "MotionMeasure"
)

############################################################
# 7. Residualize ONLY brain signal
############################################################

plot_data <- plot_data %>%
  group_by(Tract) %>%
  group_modify(~ {
    
    df <- .x %>%
      filter(!is.na(SSIRater1), !is.na(Mean_logFC))
    
    if (nrow(df) < (length(covariates) + 5)) {
      df$logFC_resid <- NA
      return(df)
    }
    
    fit_y <- lm(
      as.formula(paste("Mean_logFC ~", paste(covariates, collapse = " + "))),
      data = df
    )
    
    df$logFC_resid <- resid(fit_y)
    
    df
  }) %>%
  ungroup()

############################################################
# 8. INTERACTION MODEL + PLOTTING
############################################################

for (tract in valid_tracts) {
  
  tract_data <- plot_data %>%
    filter(Tract == tract) %>%
    filter(!is.na(logFC_resid), !is.na(SSIRater1), !is.na(Group))
  
  if (nrow(tract_data) < 10) next
  
  ##########################################################
  # Fit interaction model
  ##########################################################
  
  fit <- lm(logFC_resid ~ SSIRater1 * Group, data = tract_data)
  coefs <- summary(fit)$coefficients
  
  b_ssi <- coefs["SSIRater1", "Estimate"]
  p_ssi <- coefs["SSIRater1", "Pr(>|t|)"]
  
  int_name <- "SSIRater1:GroupRecovered"
  b_int <- if (int_name %in% rownames(coefs)) coefs[int_name, "Estimate"] else NA
  p_int <- if (int_name %in% rownames(coefs)) coefs[int_name, "Pr(>|t|)"] else NA
  
  b_recovered <- b_ssi + b_int
  
  ##########################################################
  # Prediction grid + CI
  ##########################################################
  
  ssi_seq <- seq(
    min(tract_data$SSIRater1, na.rm = TRUE),
    max(tract_data$SSIRater1, na.rm = TRUE),
    length.out = 100
  )
  
  pred_grid <- expand.grid(
    SSIRater1 = ssi_seq,
    Group = levels(tract_data$Group)
  )
  
  preds <- predict(fit, newdata = pred_grid, se.fit = TRUE)
  
  pred_grid$fit <- preds$fit
  pred_grid$se  <- preds$se.fit
  
  pred_grid$upper <- pred_grid$fit + 1.96 * pred_grid$se
  pred_grid$lower <- pred_grid$fit - 1.96 * pred_grid$se
  
  ##########################################################
  # Label
  ##########################################################
  
  label_text <- paste0(
    "Persistent slope: ", sprintf("%.2f", b_ssi),
    "\nRecovered slope: ", sprintf("%.2f", b_recovered),
    "\nInteraction p = ",
    ifelse(p_int < 0.001, "< .001", sprintf("%.3f", p_int))
  )
  
  ##########################################################
  # Plot
  ##########################################################
  
  p <- ggplot(tract_data, aes(x = SSIRater1, y = logFC_resid, color = Group)) +
    
    geom_point(alpha = 0.7, size = 1.8) +
    
    # confidence intervals (the “grey regions”)
    geom_ribbon(
      data = pred_grid,
      inherit.aes = FALSE,
      aes(
        x = SSIRater1,
        ymin = lower,
        ymax = upper,
        fill = Group
      ),
      alpha = 0.2,
      color = NA
    ) +
    
    # regression lines
    geom_line(
      data = pred_grid,
      aes(x = SSIRater1, y = fit, color = Group),
      linewidth = 1.2
    ) +
    
    scale_color_manual(values = c(
      "Persistent" = "#E64B35",
      "Recovered" = "#4DBBD5"
    )) +
    
    scale_fill_manual(values = c(
      "Persistent" = "#E64B35",
      "Recovered" = "#4DBBD5"
    )) +
    
    labs(
      title = tract,
      x = "Stuttering Severity (SSI)",
      y = "Covariate-adjusted logFC"
    ) +
    
    annotate(
      "text",
      x = max(tract_data$SSIRater1, na.rm = TRUE),
      y = max(tract_data$logFC_resid, na.rm = TRUE),
      label = label_text,
      hjust = 1,
      vjust = 1,
      size = 3.2
    ) +
    
    theme_classic(base_family = "Arial") +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold"),
      axis.text = element_text(size = 10),
      axis.title = element_text(size = 12)
    )
  
  print(p)
}

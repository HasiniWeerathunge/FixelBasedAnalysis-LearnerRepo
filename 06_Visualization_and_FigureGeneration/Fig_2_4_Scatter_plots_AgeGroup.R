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
# 2. Load tract-level data
############################################################

load_direction <- function(folder, direction){
  
  wb <- read.csv(paste0(folder,"/SIG_mean_logFC_WholeBrain.csv"))
  wb$Tract <- "WholeBrain"
  
  tracts <- read.csv(paste0(folder,"/SIG_mean_logFC_all.csv"))
  
  bind_rows(wb, tracts) %>%
    mutate(Direction = direction)
}

all_data <- load_direction("GroupAgeInteraction_positive", "Positive")

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
# 4. Merge + group definition (MATCH CLUSTER SCRIPT)
############################################################

data_final <- all_long %>%
  left_join(demo, by = "Subject") %>%
  mutate(
    Age_centered = as.numeric(Age_centered),
    VIQ_centered = as.numeric(VIQ_centered),
    TIV_centered = as.numeric(TIV_centered),
    SES_centered = as.numeric(SES_centered),
    MotionMeasure = as.numeric(MotionMeasure),
    
    Sex = as.factor(Sex),
    Site = as.factor(Site),
    
    Group = case_when(
      Group == 0 ~ "Control",
      Group == 1 & Persistent == 1 ~ "Persistent",
      Group == 1 & Recovered == 1 ~ "Recovered",
      TRUE ~ NA_character_
    ),
    Group = factor(Group, levels = c("Control", "Persistent", "Recovered"))
  ) %>%
  filter(!is.na(Group))

############################################################
# 5. Reconstruct Age
############################################################

mean_age <- 67.41520468

data_final <- data_final %>%
  mutate(Age = Age_centered + mean_age)

############################################################
# 6. ROI selection (UNCHANGED)
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
# 7. Loop over tracts (MATCH CLUSTER SCRIPT)
############################################################

for (tr in valid_tracts) {
  
  tr_data <- plot_data %>%
    filter(Tract == tr)
  
  if (all(is.na(tr_data$Age))) next
  
  ############################################################
  # Residualize covariates ONLY (preserve Age + Group)
  ############################################################
  
  cov_model <- lm(
    Mean_logFC ~ 
      Sex + VIQ_centered + TIV_centered +
      Site + SES_centered + MotionMeasure,
    data = tr_data
  )
  
  tr_data <- tr_data %>%
    mutate(Mean_logFC_resid = resid(cov_model))
  
  ############################################################
  # y-axis scaling
  ############################################################
  
  ymax <- max(tr_data$Mean_logFC_resid, na.rm = TRUE)
  ymin <- min(tr_data$Mean_logFC_resid, na.rm = TRUE)
  y_range <- c(ymin, ymax) * 1.1
  
  ############################################################
  # Regression stats per group
  ############################################################
  
  reg_stats <- tr_data %>%
    group_by(Group) %>%
    do({
      fit <- lm(Mean_logFC_resid ~ Age, data = .)
      
      slope <- coef(fit)[2]
      r2 <- summary(fit)$r.squared
      
      data.frame(
        p_value = summary(fit)$coefficients[2,4],
        r2 = r2,
        r = sign(slope) * sqrt(r2)
      )
    }) %>%
    ungroup() %>%
    mutate(
      label = paste0(
        "r = ", sprintf("%.2f", r),
        ", ",
        ifelse(p_value < 0.001, "p < .001",
               ifelse(p_value < 0.01,  "p < .01",
                      ifelse(p_value < 0.05,  "p < .05",
                             paste0("p = ", sprintf("%.3f", p_value)))))
      ),
      y_pos = seq(
        from = ymax * 0.95,
        by = -0.08 * (ymax - ymin),
        length.out = n()
      )
    )
  
  ############################################################
  # Plot (MATCH CLUSTER STYLE)
  ############################################################
  
  p <- ggplot(tr_data, aes(x = Age, y = Mean_logFC_resid, color = Group)) +
    
    geom_point(size = 1.5, alpha = 0.6) +
    
    geom_smooth(
      aes(group = Group),
      method = "lm",
      se = TRUE,
      level = 0.95,
      linewidth = 1.2,
      alpha = 0.2
    ) +
    
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    
    scale_color_manual(
      values = c(
        "Control" = "#196B24",
        "Persistent" = "#E64B35",
        "Recovered" = "#4DBBD5"
      )
    ) +
    
    scale_y_continuous(limits = y_range) +
    
    labs(
      title = paste0("Tract: ", tr),
      x = "Age (months)",
      y = "Mean log FC (covariate-adjusted)"
    ) +
    
    theme_classic(base_family = "Arial") +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold"),
      axis.text = element_text(size = 10),
      axis.title = element_text(size = 12)
    )
  
  ############################################################
  # Add regression annotations
  ############################################################
  
  p <- p +
    geom_text(
      data = reg_stats,
      aes(
        x = max(tr_data$Age, na.rm = TRUE),
        y = y_pos,
        label = label,
        color = Group
      ),
      hjust = 1,
      size = 4,
      inherit.aes = FALSE,
      show.legend = FALSE
    )
  
  print(p)
}

library(dplyr)
library(ggplot2)
library(tidyr)
library(ggdist)

setwd("/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template_cohort1and2_all/SIG_mean_logFC/")

############################################################
# 1 Load demographics
############################################################

demo <- read.csv("mean_logFC_dataset_persistent_recovered.csv")

############################################################
# 2 Load data
############################################################

load_direction <- function(folder, direction){
  
  wb <- read.csv(paste0(folder,"/SIG_mean_logFC_WholeBrain.csv")) %>%
    mutate(Tract="WholeBrain")
  
  tracts <- read.csv(paste0(folder,"/SIG_mean_logFC_all.csv"))
  
  bind_rows(wb, tracts) %>%
    mutate(Direction=direction)
}

#all_data <- load_direction("Group_effect_positive","Positive")

all_data <- load_direction("Group_effect_negative","Negative")

############################################################
# 3 Pivot thresholds
############################################################

all_long <- all_data %>%
  pivot_longer(
    cols = starts_with("MeanLogFC"),
    names_to="Threshold",
    values_to="Mean_logFC"
  ) %>%
  mutate(
    Threshold = recode(Threshold,
                       MeanLogFC="AllFixelMean",
                       MeanLogFC_FWE_05="p_FWE<.05",
                       MeanLogFC_FWE_005="p_FWE<.005",
                       MeanLogFC_unc_001="p_uncorrected<.001",
                       MeanLogFC_unc_0025="p_uncorrected<.0025",
                       MeanLogFC_unc_005="p_uncorrected<.005"
    )
  )

############################################################
# 4 Merge demographics
############################################################

data_final <- all_long %>%
  left_join(demo, by="Subject") %>%
  mutate(
    Group = case_when(
      Group == 0 ~ "Control",
      Group == 1 ~ "Stuttering",
      TRUE ~ NA_character_
    ),
    Group = factor(Group, levels = c("Control", "Stuttering")),
    Sex   = factor(Sex)
  )

############################################################
# 5 Highest threshold per tract
############################################################

highest_threshold_per_tract <- data_final %>%
  distinct(Tract) %>%
  mutate(
    HighestThreshold = ifelse(
      Tract == "WholeBrain",
      "p_uncorrected<.001",
      "p_FWE<.05"
    ),
    PanelLabel = paste0(Tract, " (", HighestThreshold, ")")
  )

############################################################
# 6 Extract datasets
############################################################

highest_threshold <- data_final %>%
  inner_join(highest_threshold_per_tract, by="Tract") %>%
  filter(Threshold==HighestThreshold)

valid_tracts <- highest_threshold %>%
  filter(!is.na(Mean_logFC)) %>%
  pull(Tract) %>%
  unique()

highest_threshold <- highest_threshold %>%
  filter(Tract %in% valid_tracts)

############################################################
# 7 GLM for significance (FULL MODEL)
############################################################

glm_results <- highest_threshold %>%
  filter(!is.na(Mean_logFC)) %>%
  group_by(Tract) %>%
  do({
    
    df <- .
    
    model <- tryCatch(
      lm(Mean_logFC ~ Group + Age_centered + Sex + VIQ_centered +
           TIV_centered + Site + SES_centered + MotionMeasure +
           Group:Age_centered + Group:Sex,
         data = df),
      error = function(e) NULL
    )
    
    if (is.null(model)) {
      return(data.frame(t_stat = NA, p_value = NA))
    }
    
    coef_summary <- summary(model)$coefficients
    
    if ("GroupStuttering" %in% rownames(coef_summary)) {
      t_stat <- coef_summary["GroupStuttering", "t value"]
      p_val  <- coef_summary["GroupStuttering", "Pr(>|t|)"]
    } else {
      t_stat <- NA
      p_val  <- NA
    }
    
    data.frame(t_stat = t_stat, p_value = p_val)
    
  }) %>%
  ungroup() %>%
  mutate(
    label = case_when(
      is.na(p_value) ~ NA_character_,
      p_value < 0.001 ~ paste0("*** (p<.001)"),
      p_value < 0.01  ~ paste0("** (p<.01)"),
      p_value < 0.05  ~ paste0("* (p<.05)"),
      TRUE ~ NA_character_
    )
  )

############################################################
# 8 Covariate-adjusted residuals (NO GROUP)
############################################################

residual_data <- highest_threshold %>%
  filter(!is.na(Mean_logFC)) %>%
  group_by(Tract) %>%
  group_modify(~{
    
    df <- .x
    
    model_cov <- tryCatch(
      lm(Mean_logFC ~ Age_centered + Sex + VIQ_centered +
           TIV_centered + Site + SES_centered + MotionMeasure,
         data = df),
      error = function(e) NULL
    )
    
    if (is.null(model_cov)) {
      df$Residuals <- NA
    } else {
      df$Residuals <- resid(model_cov)
    }
    
    df
  }) %>%
  ungroup()

############################################################
# 9 Summary stats (from residuals)
############################################################

summary_residuals <- residual_data %>%
  group_by(Group, Tract, PanelLabel) %>%
  summarise(
    Mean = mean(Residuals, na.rm = TRUE),
    SE = sd(Residuals, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  )

# ############################################################
# # 10 Plot
# ############################################################
# 
for (tract in valid_tracts) {

  summary_tract <- summary_residuals %>%
    filter(Tract == tract)

  ymax <- max(summary_tract$Mean + summary_tract$SE, na.rm = TRUE) * 1.2

  sig_labels <- glm_results %>%
    filter(Tract == tract, !is.na(label)) %>%
    mutate(
      y_pos = ymax * 1.05,
      x_start = 1,
      x_end   = 2,
      x_mid   = 1.5
    )

  p1 <- ggplot(summary_tract, aes(Group, Mean)) +

    geom_bar(
      stat = "identity",
      width = .4,
      aes(fill = Group),
      alpha = .7,
      color = "black"
    ) +

    geom_errorbar(
      aes(ymin = Mean - SE, ymax = Mean + SE),
      width = .2
    ) +

    scale_fill_manual(
      values = c(
        "Control" = "#196B24",
       "Stuttering" = "#E64B35"
      )
    ) +

    labs(
      title = unique(summary_tract$PanelLabel),
      y = "Covariate-adjusted Mean log FC",
      x = ""
    ) +

    theme_minimal(base_size = 16) +
    theme(
      plot.title = element_text(hjust = .5, face = "bold")
    )

  # significance annotation
  p1 <- p1 +
    geom_segment(
      data = sig_labels,
      aes(x = x_start, xend = x_end, y = y_pos, yend = y_pos),
      #size = 8,
      inherit.aes = FALSE
    ) +

    geom_text(
      data = sig_labels,
      aes(x = x_mid, y = y_pos, label = label),
      inherit.aes = FALSE,
      size = 5,
      fontface = "bold",
      vjust = -0.5
    )

  print(p1)
}

############################################################
# 10 Raincloud Plot (covariate-adjusted residuals)
############################################################

for (tract in valid_tracts) {
  
  plot_data <- residual_data %>%
    filter(Tract == tract, !is.na(Residuals))
  
  ymax <- max(plot_data$Residuals, na.rm = TRUE) * 1.2
  
  sig_labels <- glm_results %>%
    filter(Tract == tract, !is.na(label)) %>%
    mutate(
      y_pos = ymax * 1.05,
      x_start = 1,
      x_end   = 2,
      x_mid   = 1.5
    )
  
  p <- ggplot(plot_data, aes(x = Group, y = Residuals, fill = Group)) +
    
    # Half-violin (raincloud "cloud")
    stat_halfeye(
      adjust = 0.6,
      width = 0.6,
      justification = -0.25,
      .width = 0,
      alpha = 0.6,
      color = NA
    ) +
    
    # Boxplot (center summary)
    geom_boxplot(
      width = 0.15,
      outlier.shape = NA,
      alpha = 0.4
    ) +
    
    # Raw data points (rain "drops")
    geom_jitter(
      width = 0.08,
      alpha = 0.6,
      size = 1.5
    ) +
    
    scale_fill_manual(
      values = c(
        "Control" = "#196B24",
        "Stuttering" = "#E64B35"
      )
    ) +
    
    labs(
      title = unique(plot_data$PanelLabel),
      y = "Covariate-adjusted residual log FC",
      x = ""
    ) +
    
    theme_minimal(base_size = 16) +
    theme(
      plot.title = element_text(hjust = .5, face = "bold"),
      legend.position = "none"
    )
  
  # significance annotation (same as before)
  p <- p +
    geom_segment(
      data = sig_labels,
      aes(x = x_start, xend = x_end, y = y_pos, yend = y_pos),
      inherit.aes = FALSE
    ) +
    geom_text(
      data = sig_labels,
      aes(x = x_mid, y = y_pos, label = label),
      inherit.aes = FALSE,
      size = 5,
      fontface = "bold",
      vjust = -0.5
    )
  
  print(p)
}

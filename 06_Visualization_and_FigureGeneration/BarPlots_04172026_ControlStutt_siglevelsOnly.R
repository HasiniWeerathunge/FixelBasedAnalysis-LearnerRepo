library(dplyr)
library(ggplot2)
library(tidyr)

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


all_data <- load_direction("Group_effect_positive","Positive")
#all_data <- load_direction("Group_effect_negative","Negative")

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
# 4 Merge demographics + collapse groups
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
    Sex   = factor(Sex),
    
    # 🔥 Center Age (important for interpreting Group effect)
   # Age_c = scale(Age, center = TRUE, scale = FALSE)
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
  filter(Threshold==HighestThreshold) %>%
  mutate(ThresholdType="Significant Fixel mean")

valid_tracts <- highest_threshold %>%
  filter(!is.na(Mean_logFC)) %>%
  pull(Tract) %>%
  unique()

highest_threshold <- highest_threshold %>%
  filter(Tract %in% valid_tracts)

uncorrected_data <- data_final %>%
  filter(
    Threshold == "AllFixelMean",
    Tract %in% valid_tracts
  ) %>%
  inner_join(highest_threshold_per_tract, by="Tract") %>%
  mutate(ThresholdType = "All Fixels Mean Value")

plot_data <- bind_rows(highest_threshold, uncorrected_data)

############################################################
# 7 Tract ordering
############################################################

tract_order <- highest_threshold %>%
  group_by(Tract, Group) %>%
  summarise(Mean = mean(Mean_logFC, na.rm=TRUE), .groups="drop") %>%
  pivot_wider(names_from = Group, values_from = Mean) %>%
  mutate(Effect = Stuttering - Control) %>%
  arrange(desc(abs(Effect))) %>%
  pull(Tract)

tract_order <- c("WholeBrain", tract_order[tract_order != "WholeBrain"])

############################################################
# 8 Summary data (for plotting)
############################################################

summary_data <- plot_data %>%
  group_by(Group,Tract,ThresholdType,PanelLabel) %>%
  summarise(
    Mean=mean(Mean_logFC,na.rm=TRUE),
    SE=sd(Mean_logFC,na.rm=TRUE)/sqrt(n()),
    .groups="drop"
  )

############################################################
# 9 GLM per tract (MATCHES MAIN MODEL)
############################################################

glm_results <- highest_threshold %>%
  filter(!is.na(Mean_logFC)) %>%
  group_by(Tract) %>%
  do({
    
    df <- .
    
    model <- tryCatch(
      lm(Mean_logFC ~ Group + Age_centered + Sex + VIQ_centered + TIV_centered + Site + SES_centered + MotionMeasure +
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
    
    data.frame(
      t_stat = t_stat,
      p_value = p_val
    )
    
  }) %>%
  ungroup() %>%
  mutate(
    label = case_when(
      is.na(p_value) ~ NA_character_,
      p_value < 0.001 ~ paste0("*** (t=", round(t_stat,2), ")"),
      p_value < 0.01  ~ paste0("** (t=", round(t_stat,2), ")"),
      p_value < 0.05  ~ paste0("* (t=", round(t_stat,2), ")"),
      TRUE ~ NA_character_
    )
  )

############################################################
# 10 Plot
############################################################

for (tract in valid_tracts) {
  
  tract_data <- plot_data %>%
    filter(Tract == tract)
  
  summary_tract <- tract_data %>%
    group_by(Group, ThresholdType, PanelLabel) %>%
    summarise(
      Mean = mean(Mean_logFC, na.rm = TRUE),
      SE = sd(Mean_logFC, na.rm = TRUE) / sqrt(n()),
      .groups = "drop"
    )
  
  ymax <- max(summary_tract$Mean + summary_tract$SE, na.rm = TRUE) * 1.2
  
  sig_labels <- glm_results %>%
    filter(Tract == tract, !is.na(label)) %>%
    mutate(
      y_pos = ymax * 1.05,
      x_start = 1,
      x_end   = 2,
      x_mid   = 1.5
    )
  
  p <- ggplot(summary_tract, aes(Group, Mean)) +
    
    geom_bar(
      data = subset(summary_tract, ThresholdType == "Significant Fixel mean"),
      stat = "identity", width = .4,
      aes(fill = Group), alpha = .7, color = "black"
    ) +
    
    geom_errorbar(
      data = subset(summary_tract, ThresholdType == "Significant Fixel mean"),
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
      y = "Mean log Fiber Cross-Section",
      x = ""
    ) +
    
    theme_minimal(base_size = 14) +
    theme(
      plot.title = element_text(hjust = .5, face = "bold")
    )
  
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

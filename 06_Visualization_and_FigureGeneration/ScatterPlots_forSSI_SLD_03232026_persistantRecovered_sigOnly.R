library(dplyr)
library(ggplot2)
library(tidyr)

setwd("/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template_cohort1and2_all/SIG_mean_logFC/")

############################################################
# 1. Load demographics
############################################################

demo <- read.csv("mean_logFC_dataset_persistent_recovered.csv")

############################################################
# 2. Load data (same structure as bar script)
############################################################

load_direction <- function(folder, direction){
  
  wb <- read.csv(paste0(folder,"/SIG_mean_logFC_WholeBrain.csv")) %>%
    mutate(Tract = "WholeBrain")
  
  tracts <- read.csv(paste0(folder,"/SIG_mean_logFC_all.csv"))
  
  bind_rows(wb, tracts) %>%
    mutate(Direction = direction)
}

all_data <- load_direction("Group_effect_positive","Positive")
#all_data <- load_direction("Group_effect_negative","Negative")
#all_data <- load_direction("GroupAgeInteraction_positive","Positive")
#all_data <- load_direction("GroupAgeInteraction_negative","Negative")

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
# 4. Merge demographics + group definition (MATCH BAR SCRIPT)
############################################################
data_final <- all_long %>%
  left_join(demo, by = "Subject") %>%
  mutate(
    Group = case_when(
      Persistent == 1 ~ "Persistent",
      Recovered == 1 ~ "Recovered",
      TRUE ~ NA_character_
    ),
    Group = factor(Group, levels = c("Persistent", "Recovered"))
  ) %>%
  filter(!is.na(Group))  # remove any NA groups
############################################################
# 5. Threshold hierarchy (same as bar script)
############################################################

threshold_priority <- c(
  "p_FWE<.05",
  "p_FWE<.005",
  "p_uncorrected<.001",
  "p_uncorrected<.0025",
  "p_uncorrected<.005"
)

############################################################
# 6. Highest threshold per tract
############################################################

highest_threshold_per_tract <- data_final %>%
  distinct(Tract) %>%
  mutate(
    HighestThreshold = case_when(
      Tract == "WholeBrain" ~ "p_uncorrected<.001",
      TRUE ~ "p_FWE<.05"
    ),
    PanelLabel = paste0(Tract, " (", HighestThreshold, ")")
  )
############################################################
# 7. Extract plotting datasets (same logic as bar script)
############################################################

highest_threshold <- data_final %>%
  inner_join(highest_threshold_per_tract, by = "Tract") %>%
  filter(Threshold == HighestThreshold) %>%
  mutate(ThresholdType = "Significant Fixel mean")

uncorrected_data <- data_final %>%
  filter(Threshold == "AllFixelMean") %>%
  inner_join(highest_threshold_per_tract, by = "Tract") %>%
  mutate(ThresholdType = "All Fixels Mean Value")

#plot_data <- bind_rows(highest_threshold, uncorrected_data)

valid_tracts <- highest_threshold %>%
  filter(!is.na(Mean_logFC)) %>%
  pull(Tract) %>%
  unique()

plot_data <- highest_threshold %>%
  filter(Tract %in% valid_tracts) %>%
  mutate(x_value = as.numeric(as.character(SSIRater1)))

############################################################
# 8. Keep only valid tracts (same philosophy as bar chart)
############################################################



plot_data <- plot_data %>%
  filter(Tract %in% valid_tracts)



############################################################
# 9. Prepare x-variable (EDIT THIS AS NEEDED)
############################################################
# Choose ONE predictor variable to plot against

plot_data <- plot_data %>%
  mutate(
    x_value = as.numeric(as.character(SSIRater1))  # or SSIRater1
  )

############################################################
# 10. Plot per tract (MATCH BAR SCRIPT LOOP)
############################################################
for (tract in valid_tracts) {
  
  tract_data <- plot_data %>% filter(Tract == tract)
  sig_data <- tract_data %>% filter(ThresholdType == "Significant Fixel mean")
  unc_data <- tract_data %>% filter(ThresholdType == "All Fixels Mean Value")
  
  if (all(is.na(tract_data$x_value))) next
  ymax <- max(sig_data$Mean_logFC, na.rm = TRUE) * 1.1
  
  # Regression stats per group
  reg_stats <- sig_data %>%
    group_by(Group) %>%
    group_modify(~ {
      df <- na.omit(.x)  # remove NAs
      
      if (nrow(df) < 2 || length(unique(df$x_value)) < 2) {
        return(tibble(p_value = NA_real_, r = NA_real_))
      }
      
      fit <- lm(Mean_logFC ~ x_value, data = df)
      coefs <- summary(fit)$coefficients
      
      if (nrow(coefs) < 2) return(tibble(p_value = NA_real_, r = NA_real_))
      
      slope <- coefs[2,1]
      r2 <- summary(fit)$r.squared
      pval <- coefs[2,4]
      
      tibble(p_value = pval, r = sign(slope) * sqrt(r2))
    }) %>%
    ungroup() %>%
    filter(!is.na(p_value)) %>%
    mutate(
      label = paste0(
        "r = ", sprintf("%.2f", r),
        ", p ",
        ifelse(p_value < 0.001, "< .001", paste0("= ", sprintf("%.3f", p_value)))
      ),
      y_pos = seq(from = max(sig_data$Mean_logFC, na.rm = TRUE) * 1.1,
                  by = -0.06 * max(sig_data$Mean_logFC, na.rm = TRUE),
                  length.out = n())
    )
  
  # Plot
  p <- ggplot() +
    geom_point(data = unc_data, aes(x = x_value, y = Mean_logFC), color = "grey70", alpha = 0.4, size = 1) +
    geom_point(data = sig_data, aes(x = x_value, y = Mean_logFC, color = Group), size = 1.5, alpha = 0.8) +
    geom_smooth(data = sig_data, aes(x = x_value, y = Mean_logFC, color = Group), method = "lm", se = TRUE, linewidth = 0.8) +
    scale_color_manual(values = c("Persistent" = "#E64B35", "Recovered" = "#4DBBD5")) +
    scale_y_continuous(limits = c(0, ymax)) +
    geom_text(data = reg_stats, aes(x = max(sig_data$x_value, na.rm = TRUE)*0.98, y = y_pos, label = label, color = Group),
              hjust = 1, size = 3, inherit.aes = FALSE, show.legend = FALSE) +
    labs(title = unique(tract_data$PanelLabel), x = "Stuttering Severity (SSI-4)", y = "Mean log Fiber Cross-Section") +
    theme_classic(base_family = "Arial") +
    theme(plot.title = element_text(hjust = 0.5, face = "bold"),
          axis.text = element_text(size = 10),
          axis.title = element_text(size = 12))
  
  print(p)
}


library(dplyr)
library(ggplot2)
library(tidyr)
library(ggdist)

setwd("/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template_cohort1and2_all/SIG_mean_logFC/")

############################################################
# 1 LOAD DEMOGRAPHICS
############################################################

demo <- read.csv("mean_logFC_dataset_persistent_recovered.csv")

############################################################
# 2 LOAD DATA
############################################################

load_direction <- function(folder, direction){
  
  wb <- read.csv(paste0(folder,"/SIG_mean_logFC_WholeBrain.csv")) %>%
    mutate(Tract = "WholeBrain")
  
  tracts <- read.csv(paste0(folder,"/SIG_mean_logFC_all.csv"))
  
  bind_rows(wb, tracts) %>%
    mutate(Direction = direction)
}

all_data <- load_direction("Group_effect_negative", "Negative")

############################################################
# 3 PIVOT THRESHOLDS
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
# 4 MERGE + DEFINE GROUPS
############################################################

data_final <- all_long %>%
  left_join(demo, by = "Subject") %>%
  mutate(
    Group = case_when(
      Group == 0 ~ "Control",
      Group == 1 & Persistent == 1 ~ "Persistent",
      Group == 1 & Recovered == 1 ~ "Recovered",
      TRUE ~ NA_character_
    ),
    Group = factor(Group, levels = c("Control", "Persistent", "Recovered")),
    
    Sex  = factor(Sex),
    Site = factor(Site)
  ) %>%
  filter(!is.na(Group))

############################################################
# 5 ROI SELECTION
############################################################

highest_threshold_per_tract <- data_final %>%
  distinct(Tract) %>%
  mutate(
    HighestThreshold = ifelse(
      Tract == "WholeBrain",
      "p_uncorrected<.001",
      "p_FWE<.05"
    )
  )

plot_data <- data_final %>%
  inner_join(highest_threshold_per_tract, by = "Tract") %>%
  filter(Threshold == HighestThreshold)

############################################################
# 6 VALID TRACTS (DATA-DRIVEN FILTER ONLY)
############################################################

valid_tracts <- plot_data %>%
  group_by(Tract) %>%
  summarise(
    n = sum(!is.na(Mean_logFC)),
    n_groups = n_distinct(Group[!is.na(Mean_logFC)]),
    .groups = "drop"
  ) %>%
  filter(n >= 10, n_groups >= 2) %>%
  pull(Tract)

plot_data <- plot_data %>%
  filter(Tract %in% valid_tracts)

############################################################
# 7 RAINCLOUD PLOTS (PLOT ONLY)
############################################################

for (tract in valid_tracts) {
  
  df <- plot_data %>%
    filter(Tract == tract, !is.na(Mean_logFC), !is.na(Group))
  
  ymax <- max(df$Mean_logFC, na.rm = TRUE)
  ymin <- min(df$Mean_logFC, na.rm = TRUE)
  y_range <- c(ymin, ymax) * 1.2
  
  p <- ggplot(df,
              aes(x = Group, y = Mean_logFC,
                  fill = Group, color = Group)) +
    
    stat_halfeye(
      adjust = 0.6,
      width = 0.6,
      justification = -0.25,
      .width = 0,
      alpha = 0.6,
      point_colour = NA
    ) +
    
    geom_boxplot(
      width = 0.15,
      outlier.shape = NA,
      alpha = 0.4
    ) +
    
    geom_jitter(
      width = 0.08,
      alpha = 0.25,
      size = 1.4,
      stroke = 0
    ) +
    
    scale_fill_manual(values = c(
      "Control" = "#196B24",
      "Persistent" = "#E64B35",
      "Recovered" = "#4DBBD5"
    )) +
    
    scale_color_manual(values = c(
      "Control" = "#196B24",
      "Persistent" = "#E64B35",
      "Recovered" = "#4DBBD5"
    )) +
    
    scale_y_continuous(limits = y_range) +
    
    labs(
      title = tract,
      x = "",
      y = "Mean log FC"
    ) +
    
    theme_classic(base_family = "Arial") +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold"),
      axis.text = element_text(size = 10),
      axis.title = element_text(size = 12),
      legend.position = "none"
    )
  
  print(p)
}

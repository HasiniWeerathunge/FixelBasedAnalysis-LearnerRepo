library(dplyr)
library(ggplot2)
library(tidyr)

setwd("/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template_cohort1and2_all/SIG_mean_logFC/")

############################################################
# 1 Load demographics
############################################################

demo <- read.csv("mean_logFC_dataset_persistent_recovered.csv")

############################################################
# 2 Load positive and negative effects
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
#all_data <- load_direction("GroupAgeInteraction_positive","Positive")
#all_data <- load_direction("GroupAgeInteraction_negative","Negative")

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

#data_final <- all_long %>%
#  left_join(demo, by="Subject") %>%
#  mutate(
#    Group=factor(Group,levels=c(0,1),labels=c("Control","Stuttering"))
#  )


data_final <- all_long %>%
  left_join(demo, by="Subject") %>%
  mutate(
    Group = case_when(
      Group == 0 ~ "Control",
      Group == 1 & Persistent == 1 ~ "Persistent",
      Group == 1 & Recovered == 1 ~ "Recovered",
      TRUE ~ NA_character_
    ),
    Group = factor(Group, levels = c("Control", "Persistent", "Recovered"))
  )




############################################################
# 5 Threshold hierarchy
############################################################

threshold_priority <- c(
  "p_FWE<.05",
  "p_FWE<.005",
  "p_uncorrected<.001",
  "p_uncorrected<.0025",
  "p_uncorrected<.005"
)


############################################################
# 6 Highest threshold per tract
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
# 7 Extract datasets for plotting
############################################################

highest_threshold <- data_final %>%
  inner_join(highest_threshold_per_tract, by="Tract") %>%
  filter(Threshold==HighestThreshold) %>%
  mutate(ThresholdType="Significant Fixel mean")

uncorrected_data <- data_final %>%
  filter(Threshold=="AllFixelMean") %>%
  inner_join(highest_threshold_per_tract, by="Tract") %>%
  mutate(ThresholdType="All Fixels Mean Value")



############################################################
# Keep only tracts with significant values at required threshold
############################################################

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

plot_data <- bind_rows(highest_threshold,uncorrected_data)
############################################################
# 8 Determine tract order by effect size
############################################################

# tract_order <- highest_threshold %>%
#   group_by(Tract,Group) %>%
#   summarise(Mean=mean(Mean_logFC,na.rm=TRUE),.groups="drop") %>%
#   pivot_wider(names_from=Group,values_from=Mean) %>%
#   mutate(Effect=Stuttering-Control) %>%
#   arrange(desc(abs(Effect))) %>%
#   pull(Tract)
# 
# tract_order <- c("WholeBrain",tract_order[tract_order!="WholeBrain"])


tract_order <- highest_threshold %>%
  group_by(Tract,Group) %>%
  summarise(Mean=mean(Mean_logFC,na.rm=TRUE),.groups="drop") %>%
  pivot_wider(names_from=Group, values_from=Mean) %>%
  mutate(
    Effect_Persistent = Persistent - Control,
    Effect_Recovered  = Recovered - Control
  ) %>%
  mutate(MaxEffect = pmax(abs(Effect_Persistent), abs(Effect_Recovered), na.rm=TRUE)) %>%
  arrange(desc(MaxEffect)) %>%
  pull(Tract)

tract_order <- c("WholeBrain", tract_order[tract_order != "WholeBrain"])



############################################################
# Effect size table (for inspection and ordering)
############################################################

# effect_size_table <- highest_threshold %>%
#   group_by(Tract, Group) %>%
#   summarise(
#     Mean = mean(Mean_logFC, na.rm = TRUE),
#     .groups = "drop"
#   ) %>%
#   pivot_wider(names_from = Group, values_from = Mean) %>%
#   mutate(
#     Effect_Persistent = Persistent - Control,
#     Effect_Recovered  = Recovered - Control
#   ) %>%
#   mutate(MaxEffect = pmax(abs(Effect_Persistent), abs(Effect_Recovered), na.rm=TRUE)) %>%
#   arrange(desc(MaxEffect)) %>%
# 
# print(effect_size_table)

############################################################
# 9 Summary data
############################################################

summary_data <- plot_data %>%
  group_by(Group,Tract,ThresholdType,PanelLabel) %>%
  summarise(
    Mean=mean(Mean_logFC,na.rm=TRUE),
    SE=sd(Mean_logFC,na.rm=TRUE)/sqrt(n()),
    .groups="drop"
  ) %>%
  complete(Group,Tract,ThresholdType,PanelLabel)

############################################################
# 10 Label positions
############################################################

label_data <- highest_threshold_per_tract %>%
  left_join(
    summary_data %>%
      group_by(Tract) %>%
      summarise(max_y=max(Mean,na.rm=TRUE),.groups="drop"),
    by="Tract"
  ) %>%
  mutate(
    y_pos=max_y+0.03,
    x_pos=1.5
  )

############################################################
# 10.5 T-test statistics per tract
############################################################

ttest_results <- highest_threshold %>%
  filter(!is.na(Mean_logFC)) %>%
  group_by(Tract) %>%
  do({
    df <- .
    
    p_CP <- tryCatch(
      t.test(Mean_logFC ~ Group,
             data = df %>% filter(Group %in% c("Control","Persistent")))$p.value,
      error = function(e) NA
    )
    
    p_CR <- tryCatch(
      t.test(Mean_logFC ~ Group,
             data = df %>% filter(Group %in% c("Control","Recovered")))$p.value,
      error = function(e) NA
    )
    
    data.frame(
      comparison = c("Control vs Persistent","Control vs Recovered"),
      p_value = c(p_CP, p_CR)
    )
  }) %>%
  ungroup() %>%
  mutate(
    label = case_when(
      is.na(p_value) ~ NA_character_,
      
      p_value < 0.001 ~ "*** (p < 0.001)",
      
      p_value < 0.01 ~ "** (p < 0.01)",
      
      p_value < 0.05 ~ "* (p < 0.05)",
      
      TRUE ~ NA_character_   #  instead of "ns"
    )
  )
############################################################
# 11 Plot
############################################################

for (tract in valid_tracts) {
  
  # Subset data for this tract
  tract_data <- plot_data %>%
    filter(Tract == tract)
  
  summary_tract <- tract_data %>%
    group_by(Group, ThresholdType, PanelLabel) %>%
    summarise(
      Mean = mean(Mean_logFC, na.rm = TRUE),
      SE = sd(Mean_logFC, na.rm = TRUE) / sqrt(n()),
      .groups = "drop"
    )
  
  ymax <- max(summary_tract$Mean + summary_tract$SE, na.rm = TRUE) * 1.1
  
  # Get significance for this tract
  sig_labels <- ttest_results %>%
    filter(Tract == tract, !is.na(label)) %>%   # 🔥 removes ns
    mutate(
      y_pos = ymax * (1.05 + (seq_len(n()) - 1) * 0.08),
      y_text = y_pos + ymax * 0.03,
      x_start = c(1, 1)[seq_len(n())],
      x_end   = c(2, 3)[seq_len(n())],
      x_mid   = (x_start + x_end) / 2
    )
  
  p <- ggplot(summary_tract, aes(Group, Mean)) +
    
   # geom_bar(
  #    data = subset(summary_tract, ThresholdType == "All Fixels Mean Value"),
  #    stat = "identity", width = .4,
  #    fill = "grey70", color = "black"
  #  ) +
    
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
    
    #scale_y_continuous(limits = c(0, ymax)) +
    scale_y_continuous() +
    
    scale_fill_manual(
      values = c(
        "Control" = "#196B24",
        "Persistent" = "#E64B35",
        "Recovered" = "#4DBBD5"
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
    # significance lines
    geom_segment(
      data = sig_labels,
      aes(x = x_start, xend = x_end, y = y_pos, yend = y_pos),
      inherit.aes = FALSE
    ) +
    
    # significance text (***, **, *)
    geom_text(
      data = sig_labels,
      aes(x = x_mid, y = y_pos, label = label),
      inherit.aes = FALSE,
      size = 5,
      fontface = "bold",
      vjust = +1.2
    )
  
  print(p)
  
  # Optional: save each figure
  # ggsave(
  #   filename = paste0("Plot_", tract, ".png"),
  #   plot = p,
  #   width = 5,
  #   height = 5,
  #   dpi = 300
  # )
}
library(dplyr)
library(ggplot2)
library(tidyr)



setwd('/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template_cohort1and2_all/SIG_mean_logFC/')

# 1. Load demographics
demo <- read.csv("mean_logFC_dataset.csv")

# 2A. Load whole brain positive effects
wb_pos <- read.csv("Group_effect_positive/SIG_mean_logFC_WholeBrain.csv") %>%
  mutate(Tract = "WholeBrain",
         Direction = "Positive")

# 3A. Load tract positive effects
tracts_pos <- read.csv("Group_effect_positive/SIG_mean_logFC_all.csv") %>%
  mutate(Direction = "Positive")

# 4A. Combine whole brain + tracts
all_pos <- bind_rows(wb_pos, tracts_pos)


# repeat for negatives
# 2B. Load whole brain negative effects
wb_neg <- read.csv("Group_effect_negative/SIG_mean_logFC_WholeBrain.csv") %>%
  mutate(Tract = "WholeBrain",
         Direction = "Negative")

# 3B. Load tract positive effects
tracts_neg <- read.csv("Group_effect_negative/SIG_mean_logFC_all.csv") %>%
  mutate(Direction = "Negative")

# 4B. Combine whole brain + tracts
all_neg <- bind_rows(wb_neg, tracts_neg)

# 5. Pivot thresholds into long format
all_long_pos <- all_pos %>%
  pivot_longer(
    cols = starts_with("MeanLogFC"),
    names_to = "Threshold",
    values_to = "Mean_logFC"
  ) %>%
  mutate(
    Threshold = case_when(
      Threshold == "MeanLogFC" ~ "AllFixelMean",
      Threshold == "MeanLogFC_FWE_05" ~ "p_FWE<.05",
      Threshold == "MeanLogFC_FWE_005" ~ "p_FWE<.005",
      Threshold == "MeanLogFC_unc_001" ~ "p_uncorrected<.001",
      Threshold == "MeanLogFC_unc_0025" ~ "p_uncorrected<.0025",
      Threshold == "MeanLogFC_unc_005" ~ "p_uncorrected<.005",
      TRUE ~ Threshold
    )
  )

# doing the same for negative
all_long_neg <- all_neg %>%
  pivot_longer(
    cols = starts_with("MeanLogFC"),
    names_to = "Threshold",
    values_to = "Mean_logFC"
  ) %>%
  mutate(
    Threshold = case_when(
      Threshold == "MeanLogFC" ~ "AllFixelMean",
      Threshold == "MeanLogFC_FWE_05" ~ "p_FWE<.05",
      Threshold == "MeanLogFC_FWE_005" ~ "p_FWE<.005",
      Threshold == "MeanLogFC_unc_001" ~ "p_uncorrected<.001",
      Threshold == "MeanLogFC_unc_0025" ~ "p_uncorrected<.0025",
      Threshold == "MeanLogFC_unc_005" ~ "p_uncorrected<.005",
      TRUE ~ Threshold
    )
  )



# 6 Merge demographics
data_final_pos <- all_long_pos %>%
  left_join(demo, by = c("Subject" = "Subject"))

data_final_neg <- all_long_neg %>%
  left_join(demo, by = c("Subject" = "Subject"))


# 7 Convert to factors
data_final_pos <- data_final_pos %>%
  mutate(
    Group = factor(Group,
                   levels = c(0,1),
                   labels = c("Control","Stuttering")),
    Tract = factor(Tract),
    Threshold = factor(Threshold,
                       #levels = c("FWE_05","FWE_005","p001","p0025","p005","uncorrected_all"),
                       levels = c("p_FWE<.05","p_FWE<.005","p_uncorrected<.001","p_uncorrected<.0025","p_uncorrected<.005","AllFixelMean"))
  )


# 7 Convert to factors
data_final_neg <- data_final_neg %>%
  mutate(
    Group = factor(Group,
                   levels = c(0,1),
                   labels = c("Control","Stuttering")),
    Tract = factor(Tract),
    Threshold = factor(Threshold,
                       #levels = c("FWE_05","FWE_005","p001","p0025","p005","uncorrected_all"),
                       levels = c("p_FWE<.05","p_FWE<.005","p_uncorrected<.001","p_uncorrected<.0025","p_uncorrected<.005","AllFixelMean"))
  )


############################################################
# 6 Define threshold hierarchy
############################################################

threshold_priority <- c(
  "p_FWE<.05","p_FWE<.005","p_uncorrected<.001","p_uncorrected<.0025","p_uncorrected<.005"
)

# Ensure Threshold is character for comparisons
data_final_pos <- data_final_pos %>%
  mutate(Threshold = as.character(Threshold))

data_final_neg <- data_final_neg %>%
  mutate(Threshold = as.character(Threshold))

data_final <-data_final_neg
############################################################
# 7 Determine highest threshold per tract and keep all subjects
############################################################


data_filtered <- data_final %>%
  filter(Threshold %in% threshold_priority) %>%
  filter(!is.na(Mean_logFC))

# Compute highest threshold per tract
highest_threshold_per_tract <- data_filtered %>%
  group_by(Tract) %>%
  summarise(
    AvailableThresholds = list(unique(Threshold)),
    .groups = "drop"
  ) %>%
  rowwise() %>%
  mutate(
    HighestThreshold = threshold_priority[threshold_priority %in% AvailableThresholds][1],
    PanelLabel = paste0(Tract, " (", HighestThreshold, ")")
  ) %>%
  select(Tract, HighestThreshold, PanelLabel)

# Keep all participants at the highest threshold
highest_threshold <- data_filtered %>%
  inner_join(highest_threshold_per_tract, by = "Tract") %>%
  filter(Threshold == HighestThreshold) %>%
  mutate(ThresholdType = "Significant Fixel mean")
############################################################
# 8 Extract uncorrected threshold
############################################################

uncorrected_data <- data_final %>%
  filter(Threshold == "AllFixelMean") %>%
  inner_join(highest_threshold_per_tract, by = "Tract") %>%
  mutate(
    ThresholdType = "All Fixels Mean Value",
  )



tract_order_df <- highest_threshold %>%
  group_by(Tract, Group,PanelLabel) %>%
  summarise(
    Mean = mean(Mean_logFC, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_wider(names_from = Group, values_from = Mean) %>%
  mutate(
    EffectSize = Stuttering - Control
  ) %>%
  arrange(desc(abs(EffectSize)))

tract_order <- as.character(tract_order_df$Tract)


tract_order <- c(
  "WholeBrain",
  tract_order[tract_order != "WholeBrain"]
)


# Combine
plot_data <- bind_rows(highest_threshold, uncorrected_data)

# Keep Tract as factor for ordering
plot_data$Tract <- factor(plot_data$Tract, levels = tract_order)

# # Create panel_levels: for each tract, pick the significant label if exists, else tract
# panel_levels <- sapply(tract_order, function(t) {
#   ph <- highest_threshold$PanelLabel[highest_threshold$Tract == t]
#   if(length(ph) > 0) ph else t
# })
# 
# # Make unique
# panel_levels <- unique(panel_levels)
# 
# # Apply to plot_data
# plot_data$PanelLabel <- factor(plot_data$PanelLabel, levels = panel_levels)
# 
# 
# 
# 
# # Optional: sort plot_data by Tract factor (for summaries)


# 2️⃣ Prepare summary_data
summary_data <- plot_data %>%
  group_by(Group, Tract, ThresholdType, PanelLabel) %>%
  summarise(
    Mean = mean(Mean_logFC, na.rm = TRUE),
    SE = sd(Mean_logFC, na.rm = TRUE)/sqrt(n()),
    .groups = "drop"
  ) %>%
  mutate(
    FillColor = case_when(
      ThresholdType == "All Fixels Mean Value" & Group == "Control" ~ "grey70",
      ThresholdType == "All Fixels Mean Value" & Group == "Stuttering" ~ "grey70",
      ThresholdType == "Significant Fixel mean" & Group == "Control" ~ "#196B24",
      ThresholdType == "Significant Fixel mean" & Group == "Stuttering" ~ "#A02B93"
    ),
    PanelLabel = factor(PanelLabel, levels = tract_order)
  )

# 3️⃣ Prepare label_data
  label_data <- highest_threshold_per_tract %>%
  left_join(
    summary_data %>%
      group_by(Tract) %>%
      summarise(max_y = max(Mean, na.rm = TRUE), .groups = "drop"),
    by = "Tract"
  ) %>%
  mutate(
    y_pos = max_y + 0.02,  # place above tallest bar
    label = HighestThreshold,
    x_pos = 1.5,     # center over the two bars
    Tract = factor(Tract, levels = tract_order)
  )




#lbel_data$PanelLabel <- factor(label_data$PanelLabel, levels = panel_levels)

# 4️⃣ ymax for plotting
ymax <- round(max(summary_data$Mean),1)

# 5️⃣ Plot
bar_plot <- ggplot(summary_data, aes(x = Group, y = Mean, fill = FillColor)) +
  geom_bar(data = subset(summary_data, ThresholdType == "All Fixels Mean Value"),
           stat = "identity", width = 0.4, position = position_dodge(width = 0.7), color = "black") +
  geom_bar(data = subset(summary_data, ThresholdType == "Significant Fixel mean"),
           stat = "identity", width = 0.4, position = position_dodge(width = 0.7), color = "black", alpha = 0.7) +
  geom_errorbar(data = subset(summary_data, ThresholdType == "Significant Fixel mean"),
                aes(ymin = Mean - SE, ymax = Mean + SE),
                width = 0.2, position = position_dodge(width = 0.7)) +
  geom_text(data = label_data, aes(x = 1.5, y = y_pos, label = label),
            inherit.aes = FALSE, size = 3, fontface = "bold") +
  facet_wrap(~Tract,scales = "free_y") +
  scale_fill_identity(guide = "legend",
                      labels = c("Sig Fixels Control", "Sig Fixels Stuttering", "All Fixels Mean")) +
  scale_y_continuous(limits = c(0, ymax)) +
  labs(title = "Group Differences in Mean Fiber Cross-Section (logFC)",
       x = "", y = "Mean log Fiber Cross-Section", fill = "Legend") +
  theme_minimal(base_size = 14) +
  theme(plot.title = element_text(hjust = 0.5, face = "bold"),
        strip.text = element_text(face = "bold"))

print(bar_plot)
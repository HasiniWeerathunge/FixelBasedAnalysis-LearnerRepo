library(dplyr)
library(ggplot2)
library(tidyr)

setwd("/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template_cohort1and2_all/SIG_mean_logFC/")

############################################################
# 1 Load demographics
############################################################

demo <- read.csv("mean_logFC_dataset.csv")

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

all_data <- load_direction("GroupAgeInteraction_positive","Positive")

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

data_final <- all_long %>%
  left_join(demo, by="Subject") %>%
  mutate(
    Group=factor(Group,levels=c(0,1),labels=c("Control","Stuttering"))
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
  filter(Threshold %in% threshold_priority,
         !is.na(Mean_logFC)) %>%
  group_by(Tract) %>%
  summarise(
    HighestThreshold = threshold_priority[
      match(TRUE, threshold_priority %in% Threshold)
    ],
    .groups="drop"
  ) %>%
  mutate(
    PanelLabel=paste0(Tract," (",HighestThreshold,")")
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

plot_data <- bind_rows(highest_threshold,uncorrected_data)

############################################################
# 8 Determine tract order by effect size
############################################################

tract_order <- highest_threshold %>%
  group_by(Tract,Group) %>%
  summarise(Mean=mean(Mean_logFC,na.rm=TRUE),.groups="drop") %>%
  pivot_wider(names_from=Group,values_from=Mean) %>%
  mutate(Effect=Stuttering-Control) %>%
  arrange(desc(abs(Effect))) %>%
  pull(Tract)

tract_order <- c("WholeBrain",tract_order[tract_order!="WholeBrain"])

############################################################
# Effect size table (for inspection and ordering)
############################################################

effect_size_table <- highest_threshold %>%
  group_by(Tract, Group) %>%
  summarise(
    Mean = mean(Mean_logFC, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_wider(names_from = Group, values_from = Mean) %>%
  mutate(
    EffectSize = Stuttering - Control
  ) %>%
  arrange(desc(abs(EffectSize)))

print(effect_size_table)

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
# 1. Filter to highest threshold significant fixels (already filtered so commented out)
scatter_data <- plot_data #%>%
#filter(HighestThreshold == TRUE)

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

sig_labels <- label_data %>%
  left_join(
    scatter_data %>%
      group_by(PanelLabel) %>%
      summarise(
        x_max = max(Age_centered, na.rm = TRUE),
        y_max = max(Mean_logFC, na.rm = TRUE),
        y_min = min(Mean_logFC, na.rm = TRUE),
        .groups = "drop"
      ),
    by = "PanelLabel"
  ) %>%
  mutate(
    x_pos = x_max,
    # place just above the correlation labels
    y_pos = y_max + 0.02*(y_max - y_min)
  )

corr_labels <- scatter_data %>%
  group_by(PanelLabel, Group) %>%
  summarise(
    r = cor(Age_centered, Mean_logFC, use = "complete.obs"),
    p = cor.test(Age_centered, Mean_logFC)$p.value,
    .groups = "drop"
  ) %>%
  # replace small p-values with threshold notation
  mutate(
    p_label = case_when(
      p < 0.001 ~ "p < .001",
      p < 0.005 ~ "p < .005",
      TRUE ~ paste0("p = ", signif(p, 2))
    ),
    label = paste0("r = ", round(r, 2), ", ", p_label)
  ) %>%
  # get panel-specific max for positioning
  left_join(
    scatter_data %>%
      group_by(PanelLabel) %>%
      summarise(
        x_max = max(Age_centered, na.rm = TRUE),
        y_max = max(Mean_logFC, na.rm = TRUE),
        y_min = min(Mean_logFC, na.rm = TRUE),
        .groups = "drop"
      ),
    by = "PanelLabel"
  ) %>%
  mutate(
    x_pos = x_max,
    # vertical offset per group
    y_pos = y_max - 0.06*(y_max - y_min) - 0.05*(as.numeric(factor(Group))-1)
  )

############################################################
# 11 Plotting the Scatter Plots
############################################################





facet_labels<- setNames(highest_threshold_per_tract$Tract,highest_threshold_per_tract$PanelLabel)

# 2. Preserve tract ordering (same order as bar charts)
scatter_data <- scatter_data %>%
  mutate(
    Tract = factor(Tract, levels = unique(Tract))
  )

# 3. Generate scatter plot
  ggplot(scatter_data, aes(x = Age_centered, y = Mean_logFC, color = Group)) +
  
  geom_point(size = 1, alpha = 0.8) +
  
  #geom_smooth(method = "lm", se = TRUE, linewidth = 0.8) +
    # regression lines with CI shading
  geom_smooth(aes(color = Group, fill = Group), 
                method = "lm", se = TRUE, linewidth = 0.8, alpha = 0.2) +
    
  
    
  facet_wrap(~PanelLabel,scales="free_y",labeller = labeller(PanelLabel =facet_labels))+
  
    # correlation labels
    geom_text(
      data = corr_labels,
      aes(x = x_pos, y = y_pos, label = label, color = Group),
      inherit.aes = FALSE,
      hjust = 1,
      size = 3
    ) +
    
    # fixel significance labels above correlation
    geom_text(
      data = sig_labels,
      aes(x = x_pos, y = y_pos, label = HighestThreshold),
      inherit.aes = FALSE,
      color = "black",
      fontface = "bold",
      hjust = 1,
      size = 3
    ) +
  
  theme_classic() +
    
  scale_color_manual(values = c("Control"="#196B24","Stuttering"="#A02B93")) +
  scale_fill_manual(values = c("Control"="#196B24","Stuttering"="#A02B93")) +
  
  labs(
    x = "Age (centered)",
    y = "Mean logFC",
    title = "Relationship between Age and logFC in Significant Fixels (Stuttering > Controls)"
  ) +
  
    # classic theme + Arial text
    theme_classic(base_family = "Arial") +
    theme(
      strip.text = element_text(face = "bold", family = "Arial"),
      axis.text = element_text(size = 10, family = "Arial"),
      axis.title = element_text(size = 12, family = "Arial"),
      plot.title = element_text(size = 14, face = "bold", family = "Arial")
    ) 

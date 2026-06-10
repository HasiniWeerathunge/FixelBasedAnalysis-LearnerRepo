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
# 11 Plot
############################################################


panel_levels <- highest_threshold_per_tract %>%
  mutate(Tract =factor(Tract, levels = tract_order)) %>%
  arrange(Tract) %>%
  pull(PanelLabel)

plot_data$PanelLabel <- factor(plot_data$PanelLabel, levels =panel_levels)
summary_data$PanelLabel <- factor(summary_data$PanelLabel, levels =panel_levels)
label_data$PanelLabel <- factor(label_data$PanelLabel, levels =panel_levels)


facet_labels<- setNames(highest_threshold_per_tract$Tract,highest_threshold_per_tract$PanelLabel)

ymax <- max(summary_data$Mean+summary_data$SE,na.rm=TRUE)*1.1

ggplot(summary_data,aes(Group,Mean))+
  
  geom_bar(
    data=subset(summary_data,ThresholdType=="All Fixels Mean Value"),
    stat="identity",width=.4,fill="grey70",color="black"
  )+
  
  geom_bar(
    data=subset(summary_data,ThresholdType=="Significant Fixel mean"),
    stat="identity",width=.4,
    aes(fill=Group),alpha=.7,color="black"
  )+
  
  geom_errorbar(
    data=subset(summary_data,ThresholdType=="Significant Fixel mean"),
    aes(ymin=Mean-SE,ymax=Mean+SE),
    width=.2
  )+
  
  geom_text(
    data=label_data,
    aes(x=x_pos,y=y_pos,label=HighestThreshold),
    inherit.aes=FALSE,size=3,fontface="bold"
  )+
  
  facet_wrap(~PanelLabel,scales="free_y",labeller = labeller(PanelLabel =facet_labels))+

  scale_y_continuous(limits=c(0,ymax))+
  
  scale_fill_manual(
    values = c(
      "Control" = "#196B24",
      "Stuttering" = "#A02B93"
    )
  ) +
  
  labs(
    title="Group Differences in Mean Fiber Cross-Section (logFC)",
    y="Mean log Fiber Cross-Section",
    x=""
  )+
  
  theme_minimal(base_size=14)+
  theme(
    plot.title=element_text(hjust=.5,face="bold"),
    strip.text=element_text(face="bold")
  )
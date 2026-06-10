library(dplyr)
library(tidyr)
library(ggplot2)
library(lme4)
library(lmerTest)

setwd("/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template_cohort1and2_all/SIG_mean_logFC/")

############################################################
# 1. Load data
############################################################

demo <- read.csv("mean_logFC_dataset_persistent_recovered.csv",
                 stringsAsFactors = FALSE)

load_direction <- function(folder){
  
  wb <- read.csv(paste0(folder,"/SIG_mean_logFC_WholeBrain.csv"))
  wb$Tract <- "WholeBrain"
  
  tracts <- read.csv(paste0(folder,"/SIG_mean_logFC_all.csv"))
  
  bind_rows(wb, tracts)
}

#all_data <- load_direction("Group_effect_positive")

all_data <- load_direction("GroupAgeInteraction_negative")

############################################################
# 2. Pivot thresholds
############################################################

all_long <- all_data %>%
  pivot_longer(
    cols = starts_with("MeanLogFC"),
    names_to = "Threshold",
    values_to = "Mean_logFC"
  )

############################################################
# 3. Merge + clean variables
############################################################

data_final <- all_long %>%
  left_join(demo, by = "Subject") %>%
  mutate(
    Age_centered = as.numeric(Age_centered),
    Mean_logFC = as.numeric(Mean_logFC),
    
    Sex = factor(Sex),
    Site = factor(Site),
    Tract = factor(Tract),
    
    Group = factor(Group, levels = c(0,1),
                   labels = c("Control","Stuttering"))
  ) %>%
  filter(!is.na(Group))

############################################################
# 4. Select ROI level
############################################################

plot_data <- data_final %>%
  filter(Threshold == "MeanLogFC_FWE_05")   # adjust if needed

if (nrow(plot_data) == 0) {
  stop("No data after threshold filtering — check Threshold labels")
}

############################################################
# 5. FILTER VALID TRACTS (IMPORTANT)
############################################################

valid_tracts <- plot_data %>%
  filter(!is.na(Mean_logFC), !is.na(Age_centered), !is.na(Group)) %>%
  group_by(Tract) %>%
  summarise(
    n = n(),
    n_group = n_distinct(Group)
  ) %>%
  filter(n >= 10, n_group >= 2) %>%
  pull(Tract)

plot_data_clean <- plot_data %>%
  filter(Tract %in% valid_tracts)

cat("Valid tracts:\n")
print(valid_tracts)

############################################################
# 6. MIXED-EFFECTS MODEL (PRIMARY ANALYSIS)
############################################################

main_model <- lmer(
  Mean_logFC ~ 
    Age_centered * Group +
    Sex + VIQ_centered + TIV_centered +
    Site + SES_centered + MotionMeasure +
    (1 | Tract),
  data = plot_data_clean,
  REML = FALSE
)

summary(main_model)

############################################################
# 7. WHOLE-BRAIN (GLOBAL) PLOT
############################################################

age_seq <- seq(min(plot_data_clean$Age_centered, na.rm=TRUE),
               max(plot_data_clean$Age_centered, na.rm=TRUE),
               length.out = 100)

pred_global <- expand.grid(
  Age_centered = age_seq,
  Group = levels(plot_data_clean$Group),
  Sex = levels(plot_data_clean$Sex)[1],
  Site = levels(plot_data_clean$Site)[1],
  VIQ_centered = mean(plot_data_clean$VIQ_centered, na.rm=TRUE),
  TIV_centered = mean(plot_data_clean$TIV_centered, na.rm=TRUE),
  SES_centered = mean(plot_data_clean$SES_centered, na.rm=TRUE),
  MotionMeasure = mean(plot_data_clean$MotionMeasure, na.rm=TRUE)
)

# FIXED EFFECTS ONLY → global trend
pred_global$fit <- predict(main_model, newdata = pred_global, re.form = NA)

p_global <- ggplot(plot_data_clean,
                   aes(Age_centered, Mean_logFC, color = Group)) +
  
  geom_point(alpha = 0.3, size = 1) +
  
  geom_line(data = pred_global,
            aes(Age_centered, fit, color = Group),
            linewidth = 1.5) +
  
  scale_color_manual(values = c("grey40","#E64B35")) +
  
  labs(
    title = "Whole-brain Age × Group effect",
    x = "Age (centered)",
    y = "Mean logFC"
  ) +
  
  theme_classic()

print(p_global)

############################################################
# 8. TRACT-SPECIFIC PLOTS (ONLY VALID TRACTS)
############################################################

p_tracts <- ggplot(plot_data_clean,
                   aes(Age_centered, Mean_logFC, color = Group)) +
  
  geom_point(alpha = 0.4, size = 1.2) +
  
  geom_smooth(method = "lm", se = FALSE, linewidth = 0.8) +
  
  facet_wrap(~ Tract, scales = "free_y") +
  
  scale_color_manual(values = c("grey40","#E64B35")) +
  
  labs(
    title = "Tract-specific Age × Group relationships",
    x = "Age (centered)",
    y = "Mean logFC"
  ) +
  
  theme_classic()

print(p_tracts)

############################################################
# 9. OPTIONAL: WHICH TRACTS WERE EXCLUDED
############################################################

excluded_tracts <- setdiff(unique(plot_data$Tract), valid_tracts)

cat("\nExcluded tracts:\n")
print(excluded_tracts)

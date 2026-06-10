library(dplyr)
library(ggplot2)
library(tidyr)

setwd("/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template_cohort1and2_all/SIG_mean_logFC/")

############################################################
# 1. Load demographics
############################################################

demo <- read.csv("mean_logFC_dataset_persistent_recovered.csv", stringsAsFactors = FALSE)

############################################################
# 2. Load data
############################################################

load_direction <- function(folder, direction){
  
  wb <- read.csv(paste0(folder,"/SIG_mean_logFC_WholeBrain.csv"))
  wb$Tract <- "WholeBrain"
  
  tracts <- read.csv(paste0(folder,"/SIG_mean_logFC_all.csv"))
  
  bind_rows(wb, tracts) %>%
    mutate(Direction = direction)
}

#all_data <- load_direction("Group_effect_positive","Positive")
#all_data <- load_direction("Group_effect_negative","Negative")
#all_data <- load_direction("GroupAgeInteraction_positive","Positive")
all_data <- load_direction("GroupAgeInteraction_negative","Negative")

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
# 4. Merge + fix types
############################################################

data_final <- all_long %>%
  left_join(demo, by = "Subject") %>%
  mutate(
    SSIRater1 = as.numeric(trimws(SSIRater1)),
    
    Age_centered = as.numeric(Age_centered),
    VIQ_centered = as.numeric(VIQ_centered),
    TIV_centered = as.numeric(TIV_centered),
    SES_centered = as.numeric(SES_centered),
    MotionMeasure = as.numeric(MotionMeasure),
    
    Sex = as.factor(Sex),
    Site = as.factor(Site),
    
    Group = case_when(
      Persistent == 1 ~ "Persistent",
      Recovered == 1 ~ "Recovered",
      TRUE ~ NA_character_
    ),
    Group = factor(Group, levels = c("Persistent", "Recovered"))
  ) %>%
  filter(!is.na(Group))

############################################################
# 5. ROI definition (Group-based)
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
# 6. Covariates (NO GROUP, NO SSI)
############################################################

covariates <- c(
  "Age_centered", "Sex", "VIQ_centered",
  "TIV_centered", "Site", "SES_centered", "MotionMeasure"
)

############################################################
# 7. RESIDUALIZE ONLY BRAIN (logFC)
############################################################

plot_data <- plot_data %>%
  group_by(Tract) %>%
  group_modify(~ {
    
    df <- .x %>%
      filter(!is.na(SSIRater1), !is.na(Mean_logFC))
    
    if (nrow(df) < (length(covariates) + 5)) {
      df$logFC_resid <- NA
      return(df)
    }
    
    fit_y <- lm(
      as.formula(paste("Mean_logFC ~", paste(covariates, collapse = " + "))),
      data = df
    )
    
    df$logFC_resid <- resid(fit_y)
    
    df
  }) %>%
  ungroup()

############################################################
# 8. PLOTTING LOOP (GROUP-SPECIFIC STATS)
############################################################

for (tract in valid_tracts) {
  
  tract_data <- plot_data %>%
    filter(Tract == tract) %>%
    filter(!is.na(logFC_resid), !is.na(SSIRater1), !is.na(Group))
  
  if (nrow(tract_data) < 10) next
  
  ##########################################################
  # GROUP-WISE MODELS
  ##########################################################
  
  stats_by_group <- tract_data %>%
    group_by(Group) %>%
    group_modify(~ {
      
      df <- .x
      
      if (nrow(df) < 5 || length(unique(df$SSIRater1)) < 2) {
        return(tibble(r = NA_real_, p = NA_real_))
      }
      
      fit_g <- lm(logFC_resid ~ SSIRater1, data = df)
      coefs <- summary(fit_g)$coefficients
      
      r_val <- cor(df$SSIRater1, df$logFC_resid, use = "complete.obs")
      p_val <- coefs["SSIRater1", "Pr(>|t|)"]
      
      tibble(r = r_val, p = p_val)
    }) %>%
    ungroup()
  
  persistent_stats <- stats_by_group %>% filter(Group == "Persistent")
  recovered_stats  <- stats_by_group %>% filter(Group == "Recovered")
  
  ##########################################################
  # LABEL
  ##########################################################
  
  label_text <- paste0(
    "Persistent: r = ", sprintf("%.2f", persistent_stats$r),
    ", p ", ifelse(persistent_stats$p < 0.001, "< .001", paste0("= ", sprintf("%.3f", persistent_stats$p))),
    "\nRecovered: r = ", sprintf("%.2f", recovered_stats$r),
    ", p ", ifelse(recovered_stats$p < 0.001, "< .001", paste0("= ", sprintf("%.3f", recovered_stats$p)))
  )
  
  ##########################################################
  # PLOT
  ##########################################################
  
  ymax <- max(tract_data$logFC_resid, na.rm = TRUE) * 1.2
  ymin <- min(tract_data$logFC_resid, na.rm = TRUE)
  
  p <- ggplot(tract_data, aes(x = SSIRater1, y = logFC_resid, color = Group)) +
    
    geom_point(alpha = 0.8, size = 1.8) +
    
    geom_smooth(method = "lm", se = TRUE, linewidth = 1) +
    
    scale_color_manual(values = c("Persistent" = "#E64B35", "Recovered" = "#4DBBD5")) +
    
    coord_cartesian(ylim = c(ymin, ymax)) +
    
    labs(
      title = tract,
      x = "Stuttering Severity (SSI)",
      y = "Mean logFC (covariate-adjusted)"
    ) +
    
    annotate(
      "text",
      x = max(tract_data$SSIRater1, na.rm = TRUE),
      y = ymax,
      label = label_text,
      hjust = 1,
      vjust = 1,
      size = 3.2
    ) +
    
    theme_classic(base_family = "Arial") +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold"),
      axis.text = element_text(size = 10),
      axis.title = element_text(size = 12)
    )
  
  print(p)
}

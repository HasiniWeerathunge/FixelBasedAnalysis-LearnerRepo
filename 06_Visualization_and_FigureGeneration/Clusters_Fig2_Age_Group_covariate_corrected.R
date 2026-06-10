library(dplyr)
library(ggplot2)
library(tidyr)
library(broom)

setwd("/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/template_cohort1and2_all/SIG_mean_logFC/")

############################################################
# 1. Load demographics
############################################################
demo <- read.csv("mean_logFC_dataset_persistent_recovered.csv")

############################################################
# 2. Load cluster-level data
############################################################
cluster_data <- read.csv("cluster_mean_logFC_per_subject.csv")

# Clean subject IDs
cluster_data$Subject <- gsub("\\.mif_1\\.mif$", "", cluster_data$Subject)

# Keep only matched subjects
cluster_data <- cluster_data %>%
  filter(Subject %in% demo$Subject)

############################################################
# 3. Merge demographics
############################################################
data_merged <- cluster_data %>%
  left_join(demo, by = "Subject") %>%
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
# 4. Reconstruct Age
############################################################
mean_age <- 67.41520468
data_merged <- data_merged %>%
  mutate(Age = Age_centered + mean_age)

############################################################
# 5. Loop over clusters
############################################################
clusters <- unique(data_merged$Cluster)

for (clus in clusters[1:7]) {
  
  clus_data <- data_merged %>%
    filter(Cluster == clus)
  
  if (all(is.na(clus_data$Age))) next
  
  ############################################################
  # 🔹 Residualize covariates ONLY (preserve Age + Group)
  ############################################################
  cov_model <- lm(
    Mean_logFC ~ 
      Sex + VIQ_centered + TIV_centered +
      Site + SES_centered + MotionMeasure,
    data = clus_data
  )
  
  clus_data <- clus_data %>%
    mutate(Mean_logFC_resid = resid(cov_model))
  
  ############################################################
  # 🔹 Per-cluster y-axis scaling
  ############################################################
  ymax <- max(clus_data$Mean_logFC_resid, na.rm = TRUE)
  ymin <- min(clus_data$Mean_logFC_resid, na.rm = TRUE)
  y_range <- c(ymin, ymax) * 1.1
  
  ############################################################
  # 🔹 Regression stats per group
  ############################################################
  reg_stats <- clus_data %>%
    group_by(Group) %>%
    do({
      fit <- lm(Mean_logFC_resid ~ Age, data = .)
      
      slope <- coef(fit)[2]
      r2 <- summary(fit)$r.squared
      
      data.frame(
        p_value = summary(fit)$coefficients[2,4],
        r2 = r2,
        r = sign(slope) * sqrt(r2)
      )
    }) %>%
    ungroup() %>%
    mutate(
      label = paste0(
        "r = ", sprintf("%.2f", r),
        ", ",
        ifelse(p_value < 0.001, "p < .001",
               ifelse(p_value < 0.01,  "p < .01",
                      ifelse(p_value < 0.05,  "p < .05",
                             paste0("p = ", sprintf("%.3f", p_value)))))
      ),
      y_pos = seq(
        from = ymax * 0.95,
        by = -0.08 * (ymax - ymin),
        length.out = n()
      )
    )
  
  ############################################################
  # 🔹 Plot
  ############################################################
  p <- ggplot(clus_data, aes(x = Age, y = Mean_logFC_resid, color = Group)) +
    
    geom_point(size = 1.5, alpha = 0.6) +
    
    # Regression lines + 95% CI
    geom_smooth(
      aes(group = Group),
      method = "lm",
      se = TRUE,
      level = 0.95,
      linewidth = 1.2,
      alpha = 0.2
    ) +
    
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    
    scale_color_manual(
      values = c(
        "Control" = "#196B24",
        "Persistent" = "#E64B35",
        "Recovered" = "#4DBBD5"
      )
    ) +
    
    scale_y_continuous(limits = y_range) +
    
    labs(
      title = paste0("Cluster ", clus),
      x = "Age (months)",
      y = "Mean log FC (covariate-adjusted)"
    ) +
    
    theme_classic(base_family = "Arial") +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold"),
      axis.text = element_text(size = 10),
      axis.title = element_text(size = 12)
    )
  
  ############################################################
  # 🔹 Add regression annotations
  ############################################################
  p <- p +
    geom_text(
      data = reg_stats,
      aes(
        x = max(clus_data$Age, na.rm = TRUE),
        y = y_pos,
        label = label,
        color = Group
      ),
      hjust = 1,
      size = 4,
      inherit.aes = FALSE,
      show.legend = FALSE
    )
  
  print(p)
  
  # Optional save
  # ggsave(paste0("Scatter_Cluster_", clus, ".png"), p, width = 5, height = 5, dpi = 300)
}

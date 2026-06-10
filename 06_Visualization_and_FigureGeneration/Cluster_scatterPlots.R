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
# 2. Load cluster-level mean logFC data
############################################################
cluster_data <- read.csv("cluster_mean_logFC_per_subject.csv")  # columns: Subject, Cluster, Threshold, Mean_logFC
# Remove the ".mif_1.mif" suffix
cluster_data$Subject <- gsub("\\.mif_1\\.mif$", "", cluster_data$Subject)

# Keep only participants present in demo
cluster_data <- cluster_data %>%
  filter(Subject %in% demo$Subject)

############################################################
# 3. Merge demographics (to get Age, Group info)
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
# 4. Compute original age from age_centered (if needed)
############################################################
mean_age <- 67.41520468  # replace with your cohort mean
data_merged <- data_merged %>%
  mutate(Age = Age_centered + mean_age)

############################################################
# 5. Loop over clusters and plot
############################################################
clusters <- unique(data_merged$Cluster)

for (clus in clusters[1:7]) {
  
  clus_data <- data_merged %>%
    filter(Cluster == clus)
  
    # Compute regression stats per cluster + group
  # Compute regression stats per cluster + group
  reg_stats <- clus_data %>%
    group_by(Group) %>%
    do({
      fit <- lm(Mean_logFC ~ Age, data = .)
      
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
        ", p = ",
        ifelse(p_value < 0.001, "< .001", sprintf("%.3f", p_value))
      ),
      
      # ✅ y positions MUST be inside mutate
      y_pos = seq(
        from = max(clus_data$Mean_logFC, na.rm = TRUE) * 1.05,
        by = -0.06 * max(clus_data$Mean_logFC, na.rm = TRUE),
        length.out = n()
      )
    )
  
  
  if (all(is.na(clus_data$Age))) next
  
  ymax <- max(clus_data$Mean_logFC, na.rm = TRUE) * 1.1
  
  
  
  p <- ggplot(clus_data, aes(x = Age, y = Mean_logFC, color = Group)) +
    geom_point(size = 1.5, alpha = 0.8) +
    geom_smooth(method = "lm", se = TRUE, linewidth = 0.8) +
    scale_color_manual(
      values = c(
        "Control" = "#196B24",
        "Persistent" = "#E64B35",
        "Recovered" = "#4DBBD5"
      )
    ) +
    scale_y_continuous(limits = c(0, ymax)) +
   
    
    labs(
      title = paste0("Cluster ", clus),
      x = "Age (months)",
      y = "Mean log Fiber Cross-Section"
    ) +
    theme_classic(base_family = "Arial") +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold"),
      axis.text = element_text(size = 10),
      axis.title = element_text(size = 12)
    )
  
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
      size = 3,
      inherit.aes = FALSE,
      show.legend = FALSE,   # 🔥 THIS FIXES THE "a"
      #parse = TRUE # enables italic +math formatting
    )
  
  print(p)
  
  # Save plots automatically
  #ggsave(paste0("Scatter_Cluster_", clus, ".png"), p, width = 5, height = 5, dpi = 300)
}

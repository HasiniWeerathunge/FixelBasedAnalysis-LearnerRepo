library(dplyr)
library(ggplot2)
library(tidyr)

# Assuming your dataset is called df
# Columns: Group, AF_meanFC, SLF_meanFC, CST_meanFC (replace with your actual names)

# List your tract columns
tract_cols <- c("AF_meanFC", "SLF_meanFC", "CST_meanFC")

# Reshape data into long format for plotting
df_long <- df %>%
  select(Group, all_of(tract_cols)) %>%
  pivot_longer(
    cols = all_of(tract_cols),
    names_to = "Tract",
    values_to = "MeanFC"
  )

# Summarize mean and SE per Group per Tract
summary_data <- df_long %>%
  group_by(Group, Tract) %>%
  summarise(
    Mean = mean(MeanFC, na.rm = TRUE),
    SE = sd(MeanFC, na.rm = TRUE)/sqrt(n()),
    .groups = "drop"
  )

# Multi-panel bar chart
p <- ggplot(summary_data, aes(x = Group, y = Mean, fill = Group)) +
  geom_bar(stat = "identity", color = "black", width = 0.6) +
  geom_errorbar(aes(ymin = Mean - SE, ymax = Mean + SE), width = 0.2) +
  scale_fill_manual(values = c("tomato","skyblue","gold")) +
  facet_wrap(~Tract, nrow = 1) +
  ylab("Mean FC") +
  xlab("") +
  theme_minimal(base_size = 14) +
  theme(legend.position = "none")

# Display plot
print(p)

# Save figure
ggsave("Figure2_tracts_meanFC.png", plot = p, width = 10, height = 4, dpi = 300)


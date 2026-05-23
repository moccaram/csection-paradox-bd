# =============================================================================
# 22_who_threshold_crossing.R
#
# Bangladesh-focused visualization of when the C-section rate crossed key
# medical/policy thresholds (10%, 15%, 20%, 25%, 30%, 40%). The 15% line is
# the WHO Statement on C-section rates ceiling for population-level benefit;
# crossings above 30% mark routine excess.
#
# Input:  data/processed/descriptive/P1_Threshold_Years.csv
#         data/processed/descriptive/P1_Csec_Trends_All.csv (Bangladesh subset)
# Output: figures/02_who_threshold_crossed.png
# Reference: WHO (2015) Statement on Caesarean Section Rates; Betran et al. 2015.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
  library(here)
})

thresholds <- read_csv(
  here("data", "processed", "descriptive", "P1_Threshold_Years.csv"),
  show_col_types = FALSE
) %>%
  filter(country == "Bangladesh", !is.na(year_crossed))

trends <- read_csv(
  here("data", "processed", "descriptive", "P1_Csec_Trends_All.csv"),
  show_col_types = FALSE
) %>%
  filter(country == "Bangladesh")

# Annotate the WHO 15% line specially
thresholds <- thresholds %>%
  mutate(
    label = sprintf("%d%%\n(%g)", threshold_pct, year_crossed),
    is_who = threshold_pct == 15
  )

p <- ggplot(trends, aes(x = year, y = csec_pct / 100)) +
  geom_line(color = "#c0392b", linewidth = 1.2) +
  geom_point(color = "#c0392b", size = 3) +
  # Horizontal threshold lines + crossing markers
  geom_hline(
    data = thresholds,
    aes(yintercept = threshold_pct / 100,
        color = is_who, linewidth = is_who),
    linetype = "dotted"
  ) +
  geom_point(
    data = thresholds,
    aes(x = year_crossed, y = threshold_pct / 100,
        size = is_who),
    color = "gray30", shape = 18
  ) +
  geom_text(
    data = thresholds,
    aes(x = year_crossed, y = threshold_pct / 100,
        label = label, fontface = ifelse(is_who, "bold", "plain")),
    nudge_y = 0.018, hjust = 1.05, size = 3.2, color = "gray20"
  ) +
  scale_color_manual(values = c(`TRUE` = "darkgreen", `FALSE` = "gray60"),
                     guide = "none") +
  scale_linewidth_manual(values = c(`TRUE` = 0.9, `FALSE` = 0.4),
                         guide = "none") +
  scale_size_manual(values = c(`TRUE` = 3.5, `FALSE` = 2.5), guide = "none") +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1),
                     breaks = c(0, 0.1, 0.15, 0.2, 0.25, 0.3, 0.4, 0.5)) +
  scale_x_continuous(breaks = seq(2004, 2024, 4)) +
  labs(
    title    = "Bangladesh: years of crossing key C-section rate thresholds",
    subtitle = "WHO 15% threshold crossed in 2010 (bold); 30% reached by 2016",
    x        = "Year",
    y        = "C-section rate, Bangladesh",
    caption  = "Source: DHS Bangladesh 2004–2022. WHO 15% line from WHO (2015)\nStatement on Caesarean Section Rates."
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title    = element_text(face = "bold"),
    plot.subtitle = element_text(color = "gray30"),
    plot.caption  = element_text(color = "gray50", hjust = 0)
  )

out_path <- here("figures", "02_who_threshold_crossed.png")
ggsave(out_path, p, width = 9, height = 6, dpi = 300)
cat("Saved:", out_path, "\n")

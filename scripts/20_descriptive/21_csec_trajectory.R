# =============================================================================
# 21_csec_trajectory.R
#
# C-section rate trajectory across DHS waves, Bangladesh (primary) with India
# and Pakistan as comparison. WHO 15% threshold annotated; hypothesized
# supply→demand regime-transition year (2011) marked.
#
# Input:  data/processed/descriptive/P1_Csec_Trends_All.csv
# Output: figures/01_csec_trajectory.png
# Reference: Sujon et al. (2025); WHO recommendation on C-section rates.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
  library(here)
})

dat <- read_csv(
  here("data", "processed", "descriptive", "P1_Csec_Trends_All.csv"),
  show_col_types = FALSE
)

p <- ggplot(dat, aes(x = year, y = csec_pct / 100, color = country, group = country)) +
  # WHO 15% threshold
  geom_hline(yintercept = 0.15, linetype = "dotted", color = "darkgreen", linewidth = 0.7) +
  annotate(
    "text", x = 2000, y = 0.165,
    label = "WHO 15% threshold", hjust = 0,
    color = "darkgreen", size = 3.5
  ) +
  # Hypothesized BD regime transition at 2011
  geom_vline(xintercept = 2011, linetype = "dashed", color = "gray40", linewidth = 0.6) +
  annotate(
    "text", x = 2011.3, y = 0.49,
    label = "Bangladesh\nregime transition\n(supply → demand)",
    hjust = 0, color = "gray40", size = 3.2, lineheight = 0.9
  ) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2.5) +
  scale_color_manual(
    values = c("Bangladesh" = "#c0392b", "India" = "#7f8c8d", "Pakistan" = "#95a5a6")
  ) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1), limits = c(0, 0.5)) +
  scale_x_continuous(breaks = seq(1995, 2025, 5)) +
  labs(
    title    = "C-section rate trajectory in South Asia, DHS/NFHS 1999–2022",
    subtitle = "Bangladesh quintuples from 4.5% to 44% in 18 years; crosses WHO 15% threshold in 2010",
    x        = "Survey year",
    y        = "C-section rate",
    color    = NULL,
    caption  = "Source: DHS Bangladesh; DHS/NFHS India; DHS Pakistan."
  ) +
  theme_minimal(base_size = 13) +
  theme(
    legend.position    = "top",
    plot.title         = element_text(face = "bold"),
    plot.subtitle      = element_text(color = "gray30"),
    plot.caption       = element_text(color = "gray50", hjust = 0)
  )

out_path <- here("figures", "01_csec_trajectory.png")
ggsave(out_path, p, width = 9, height = 6, dpi = 300)
cat("Saved:", out_path, "\n")

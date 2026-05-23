# =============================================================================
# 23_sector_decomposition.R
#
# Bangladesh: private-vs-public C-section share over time. Demonstrates the
# economic transition: the private sector both performs C-sections at a much
# higher rate AND captures an ever-larger share of total deliveries.
#
# Top panel:    C-section rate WITHIN each sector (private vs public)
# Bottom panel: Sector share of all C-section deliveries (the demand shift)
#
# Input:  data/processed/descriptive/P1_Sector_Decomp_All.csv
# Output: figures/03_sector_decomposition.png
# Reference: Sujon et al. (2025); PMC11289978 (urgent need to address rising
#            C-sections in LMICs); private-sector dominance per AJOG/PLOS One.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(readr)
  library(patchwork)
  library(here)
})

dat <- read_csv(
  here("data", "processed", "descriptive", "P1_Sector_Decomp_All.csv"),
  show_col_types = FALSE
) %>%
  filter(country == "Bangladesh") %>%
  mutate(sector = factor(sector, levels = c("Public", "Private")))

# Panel A: C-section rate within each sector
pA <- ggplot(dat, aes(x = year, y = csec_pct / 100,
                      color = sector, group = sector)) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2.5) +
  scale_color_manual(values = c(Public = "#2c3e50", Private = "#e74c3c")) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(
    title    = "A. C-section rate within each sector",
    subtitle = "Private sector: 55% (2004) → 84% (2022). Public stays near 35%.",
    x = NULL, y = "C-section rate", color = "Sector"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "top",
        plot.title    = element_text(face = "bold"),
        plot.subtitle = element_text(color = "gray30"))

# Panel B: Sector share of total C-section deliveries
pB <- ggplot(dat, aes(x = year, y = sector_share_pct / 100,
                      fill = sector)) +
  geom_area(alpha = 0.85) +
  scale_fill_manual(values = c(Public = "#2c3e50", Private = "#e74c3c")) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(
    title    = "B. Share of all deliveries that are C-sections, by sector",
    subtitle = "Private sector dominates the rise; public sector contribution flat",
    x = "Year", y = "Share of all deliveries", fill = "Sector"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "top",
        plot.title    = element_text(face = "bold"),
        plot.subtitle = element_text(color = "gray30"))

combined <- pA / pB +
  plot_annotation(
    title    = "Bangladesh's C-section surge is a private-sector phenomenon",
    caption  = "Source: DHS Bangladesh 2004–2022 (P1_Sector_Decomp_All.csv).",
    theme = theme(
      plot.title = element_text(face = "bold", size = 14),
      plot.caption = element_text(color = "gray50", hjust = 0)
    )
  )

out_path <- here("figures", "03_sector_decomposition.png")
ggsave(out_path, combined, width = 9, height = 9, dpi = 300)
cat("Saved:", out_path, "\n")

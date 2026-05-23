# =============================================================================
# 25_mortality_trends.R
#
# Under-five mortality trends in Bangladesh by cause across DHS waves
# (2004, 2011, 2018, 2022). Shows the secular decline in U5MR alongside
# changing cause composition — the backdrop against which the C-section
# regime transition unfolded.
#
# Input:  data/processed/descriptive/u5mr_estimates.csv
# Output: figures/05_mortality_trends.png
# Reference: Mortality decomposition by cause-specific mortality rate (CSMR);
#            secular trends in nutrition/sanitation/vaccines explain most of
#            the U5MR decline independent of C-section access.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
  library(here)
})

dat <- read_csv(
  here("data", "processed", "descriptive", "u5mr_estimates.csv"),
  show_col_types = FALSE
)

# Total U5MR by year (sum of cause-specific CSMRs)
total <- dat %>%
  group_by(year) %>%
  summarise(
    u5mr_total = sum(combined_CSMR, na.rm = TRUE),
    .groups = "drop"
  )

# Top 6 leading causes by 2004 baseline
top_causes <- dat %>%
  filter(year == 2004) %>%
  arrange(desc(combined_CSMR)) %>%
  slice_head(n = 6) %>%
  pull(cause)

dat_top <- dat %>%
  filter(cause %in% top_causes) %>%
  mutate(cause = factor(cause, levels = top_causes))

# Plot: cause-specific CSMR trajectories
p <- ggplot(dat_top, aes(x = year, y = combined_CSMR,
                         color = cause, group = cause)) +
  geom_line(linewidth = 1.0) +
  geom_point(size = 2.2) +
  geom_ribbon(
    aes(ymin = bootstrap_lower_csmr, ymax = bootstrap_upper_csmr,
        fill = cause),
    alpha = 0.10, color = NA
  ) +
  geom_line(
    data = total,
    aes(x = year, y = u5mr_total),
    inherit.aes = FALSE,
    color = "black", linewidth = 1.4, linetype = "solid"
  ) +
  geom_point(
    data = total,
    aes(x = year, y = u5mr_total),
    inherit.aes = FALSE,
    color = "black", size = 3
  ) +
  annotate(
    "text", x = 2022, y = total$u5mr_total[total$year == 2022] + 5,
    label = "Total U5MR", hjust = 1, fontface = "bold", size = 3.2
  ) +
  scale_x_continuous(breaks = c(2004, 2011, 2018, 2022)) +
  labs(
    title    = "Bangladesh: under-five cause-specific mortality, 2004–2022",
    subtitle = "Total U5MR fell from ~108 to ~37 per 1000; cause composition shifted",
    x        = "Survey year",
    y        = "Cause-specific mortality rate (per 1,000 live births)",
    color    = "Cause", fill = "Cause",
    caption  = "Source: BDHS cause-of-death estimates (u5mr_estimates.csv).\nRibbons show bootstrap 95% CI per cause."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position    = "right",
    plot.title         = element_text(face = "bold"),
    plot.subtitle      = element_text(color = "gray30"),
    plot.caption       = element_text(color = "gray50", hjust = 0)
  )

out_path <- here("figures", "05_mortality_trends.png")
ggsave(out_path, p, width = 11, height = 6, dpi = 300)
cat("Saved:", out_path, "\n")

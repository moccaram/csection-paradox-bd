# =============================================================================
# 54_chow_descriptive_break.R — Phase D modern inference: predetermined Chow
# test of a structural break in Bangladesh's C-section trajectory at 2011.
#
# WHY NOT BAI-PERRON: With T=6 DHS waves, the asymptotic theory underlying
# Bai-Perron's supF test fails (needs T ≥ 50). The honest alternative is a
# Chow test at a PREDETERMINED break-date — chosen ex ante from external
# knowledge — which has standard F-distribution under H0.
#
# Break-date 2011 is justified externally: Sujon et al. (2025) document
# Bangladesh's national C-section rate crossing the WHO 15% threshold ~2010;
# the brief's argument is that the supply→demand regime transition crystallized
# around this point.
#
# Statistical significance is constrained by T=6; the descriptive plot is the
# primary showcase asset; the Chow F-statistic is reported alongside as a
# directional indicator only.
#
# Input:  data/processed/descriptive/P1_Csec_Trends_All.csv
# Output: outputs/phase_d/chow_test_2011.csv
#         figures/phase_d/chow_descriptive_break.png
#
# References:
#   Chow GC (1960). Tests of equality between sets of coefficients in two
#   linear regressions. Econometrica 28(3): 591-605.
#   Sujon et al. (2025) — Bangladesh C-section trajectory.
#   WHO (2015) Statement on Caesarean Section Rates.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
  library(here)
})

# ---- Load Bangladesh wave-level data
csec <- read_csv(
  here("data", "processed", "descriptive", "P1_Csec_Trends_All.csv"),
  show_col_types = FALSE
) %>%
  filter(country == "Bangladesh") %>%
  arrange(year)

cat("Bangladesh wave-level trajectory:\n")
print(csec)
cat("\n")

# ---- Chow test at predetermined break-date 2011
csec <- csec %>%
  mutate(
    post_2011 = as.integer(year >= 2011),
    year_c    = year - 2011  # centered
  )

fit_pooled <- lm(csec_pct ~ year_c, data = csec)
fit_split  <- lm(csec_pct ~ year_c * post_2011, data = csec)
chow       <- anova(fit_pooled, fit_split)

cat("Chow test:\n")
print(chow)

results <- tibble(
  test                  = "Chow test at predetermined break 2011",
  F_stat                = chow$F[2],
  df1                   = chow$Df[2],
  df2                   = chow$Res.Df[2],
  p_value               = chow$`Pr(>F)`[2],
  pre_2011_slope        = coef(fit_split)["year_c"],
  post_2011_slope_diff  = coef(fit_split)["year_c:post_2011"],
  note                  = paste("T = 6 DHS waves; statistical significance constrained.",
                                "Plot is the primary showcase.")
)

out_csv <- here("outputs", "phase_d", "chow_test_2011.csv")
write_csv(results, out_csv)
cat("\nSaved:", out_csv, "\n")
print(results)

# ---- Descriptive plot
p <- ggplot(csec, aes(x = year, y = csec_pct / 100)) +
  # WHO 15% threshold (horizontal)
  geom_hline(yintercept = 0.15, linetype = "dotted",
             color = "darkgreen", linewidth = 0.7) +
  annotate("text", x = 2003, y = 0.165,
           label = "WHO 15% threshold", hjust = 0,
           color = "darkgreen", size = 3.5) +
  # 2011 break (vertical)
  geom_vline(xintercept = 2011, linetype = "dashed",
             color = "red", linewidth = 0.7) +
  annotate("text", x = 2011.3, y = 0.45,
           label = "Hypothesized\nregime transition\n(2011)",
           hjust = 0, color = "red", size = 3.3, lineheight = 0.9) +
  # Trajectory
  geom_line(linewidth = 1.3, color = "steelblue") +
  geom_point(size = 4, color = "steelblue") +
  # Fitted lines pre/post 2011
  geom_smooth(
    data = filter(csec, year <  2011),
    aes(x = year, y = csec_pct / 100),
    method = "lm", se = FALSE, color = "#27ae60",
    linewidth = 0.7, linetype = "solid"
  ) +
  geom_smooth(
    data = filter(csec, year >= 2011),
    aes(x = year, y = csec_pct / 100),
    method = "lm", se = FALSE, color = "#c0392b",
    linewidth = 0.7, linetype = "solid"
  ) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1),
                     limits = c(0, 0.5)) +
  scale_x_continuous(breaks = seq(2004, 2022, 4)) +
  labs(
    title    = "Bangladesh C-section trajectory with predetermined break at 2011",
    subtitle = sprintf("Pre-2011 slope vs. post-2011 slope. Chow F = %.2f, p = %.3f (T=6, underpowered).",
                       results$F_stat, results$p_value),
    x = "Year",
    y = "C-section rate, Bangladesh",
    caption = "Sources: DHS Bangladesh 2004–2022 (P1_Csec_Trends_All.csv); Sujon et al. 2025;\nWHO (2015) Statement on Caesarean Section Rates."
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title    = element_text(face = "bold"),
    plot.subtitle = element_text(color = "gray30"),
    plot.caption  = element_text(color = "gray50", hjust = 0)
  )

out_png <- here("figures", "phase_d", "chow_descriptive_break.png")
ggsave(out_png, p, width = 9, height = 6, dpi = 300)
cat("Saved:", out_png, "\n")

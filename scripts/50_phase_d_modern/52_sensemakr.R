# =============================================================================
# 52_sensemakr.R — Phase D modern inference: Cinelli-Hazlett (2020) OVB
# sensitivity analysis on a linear-probability model per DHS wave.
#
# Per wave, fits an LPM of child_died ~ c_section + controls, then computes
# the robustness value (RV): the minimum partial R² that an unmeasured
# confounder would need to have with BOTH treatment and outcome to reduce
# the effect to zero (or to statistical non-significance at α=0.05).
#
# Benchmarks against the observed strongest covariates (mother_education,
# infrastructure_index, residence_urban) to give a substantive yardstick.
#
# Input:  outputs/causal_main/data_step1_complete.rds
# Output: outputs/phase_d/sensemakr_summary.csv
#         figures/phase_d/sensemakr_<wave>_contour.png  (per wave)
#         figures/phase_d/sensemakr_<wave>_extreme.png  (per wave)
#
# Reference:
#   Cinelli C, Hazlett C (2020). Making sense of sensitivity: extending omitted
#   variable bias. Journal of the Royal Statistical Society Series B 82(1):39-67.
#   doi: 10.1111/rssb.12348
# =============================================================================

suppressPackageStartupMessages({
  library(sensemakr)
  library(dplyr)
  library(ggplot2)
  library(readr)
  library(here)
})

# ---- Load data
df <- readRDS(here("outputs", "causal_main", "data_step1_complete.rds"))

# Reconstruct year as a factor (script_3 logic)
df$year <- with(df, case_when(
  year_2011      == 1               ~ "2011",
  year_2017_2018 == 1               ~ "2017-2018",
  year_2022      == 1               ~ "2022",
  TRUE                              ~ "2004"
))

# Control set (variables in the data). Adding `infrastructure_index` and
# `wealth` so they're available as Cinelli-Hazlett benchmark covariates.
controls <- c(
  "birth_single", "mother_education", "partner_edu",
  "media_exposure", "mother_working", "pregnancy_terminated",
  "residence_urban", "infrastructure_index", "wealth"
)
controls <- intersect(controls, names(df))

# Benchmark variables for substantive yardstick (Cinelli-Hazlett style)
benchmark_vars <- c("mother_education", "infrastructure_index", "residence_urban")
benchmark_present <- intersect(benchmark_vars, controls)
cat("Benchmark covariates available:", paste(benchmark_present, collapse=", "), "\n")

# ---- Loop over waves
summary_rows <- list()
waves <- c("2004", "2011", "2017-2018", "2022")

for (yr in waves) {
  df_yr <- df %>% filter(year == yr)
  if (nrow(df_yr) < 100) next

  fmla <- as.formula(
    paste("child_died ~ c_section_yes +", paste(controls, collapse = " + "))
  )
  fit <- lm(fmla, data = df_yr)

  sens <- sensemakr(
    model                = fit,
    treatment            = "c_section_yes",
    benchmark_covariates = benchmark_present,
    kd                   = c(1, 2, 3),
    ky                   = c(1, 2, 3),
    q                    = 1
  )

  s <- sens$sensitivity_stats
  summary_rows[[yr]] <- tibble(
    Year                  = yr,
    N                     = nrow(df_yr),
    estimate              = s$estimate,
    se                    = s$se,
    robustness_value_q1   = s$rv_q,
    robustness_value_q1_a = s$rv_qa,
    partial_r2_yd_x       = s$r2yd.x
  )

  # ---- Figures
  png(
    here("figures", "phase_d", sprintf("sensemakr_%s_contour.png", gsub("-", "_", yr))),
    width = 1800, height = 1400, res = 200
  )
  plot(sens, type = "contour")
  dev.off()

  png(
    here("figures", "phase_d", sprintf("sensemakr_%s_extreme.png", gsub("-", "_", yr))),
    width = 1800, height = 1400, res = 200
  )
  plot(sens, type = "extreme")
  dev.off()
}

sens_summary <- bind_rows(summary_rows)
print(sens_summary)

out_csv <- here("outputs", "phase_d", "sensemakr_summary.csv")
write_csv(sens_summary, out_csv)
cat("Saved:", out_csv, "\n")

# ---- Side-by-side bar chart of robustness values across waves
p <- ggplot(sens_summary, aes(x = Year, y = robustness_value_q1 * 100)) +
  geom_col(fill = "#2980b9", alpha = 0.85, width = 0.55) +
  geom_text(
    aes(label = sprintf("%.1f%%", robustness_value_q1 * 100)),
    vjust = -0.5, size = 4, fontface = "bold"
  ) +
  labs(
    title    = "Robustness value (RV) per wave — Cinelli-Hazlett 2020",
    subtitle = "Minimum partial R² an unmeasured confounder needs with BOTH treatment and outcome to nullify the effect",
    x = "DHS wave",
    y = "Robustness value (partial R²)",
    caption  = "Lower RV → result more easily nullified by an unmeasured confounder.\nBenchmarks: mother_education, infrastructure_index, residence_urban."
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title    = element_text(face = "bold"),
    plot.subtitle = element_text(color = "gray30"),
    plot.caption  = element_text(color = "gray50", hjust = 0)
  )

out_png <- here("figures", "phase_d", "sensemakr_RV_per_wave.png")
ggsave(out_png, p, width = 9, height = 6, dpi = 300)
cat("Saved:", out_png, "\n")

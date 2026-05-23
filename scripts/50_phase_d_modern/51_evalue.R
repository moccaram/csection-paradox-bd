# =============================================================================
# 51_evalue.R — Phase D modern inference: E-value (VanderWeele & Ding 2017)
#
# Reads the wave-stratified C-section ATE from the RBVP pipeline and computes
# the E-value: the minimum strength (risk-ratio scale) that an unmeasured
# confounder would need to have with BOTH treatment and outcome to fully
# explain the observed association.
#
# Input:  outputs/causal_main/Formal_ATE_Results.csv
# Output: outputs/phase_d/evalue_csection.csv
#         figures/phase_d/evalue_per_wave.png
#
# Reference:
#   VanderWeele TJ, Ding P (2017). Sensitivity Analysis in Observational
#   Research: Introducing the E-Value. Annals of Internal Medicine.
#   doi: 10.7326/M16-2607
#
# Interpretation rubric:
#   E < 1.5    trivially overturnable; result is fragile
#   1.5 < 2.0  weak result
#   2.0 < 3.0  moderate
#   E > 3.0    robust
# =============================================================================

suppressPackageStartupMessages({
  library(EValue)
  library(dplyr)
  library(ggplot2)
  library(readr)
  library(here)
})

# ---- Load the RBVP wave-stratified ATE results
ates <- read_csv(
  here("outputs", "causal_main", "Formal_ATE_Results.csv"),
  show_col_types = FALSE
) %>%
  rename(
    ATE_pp      = Csec_ATE,
    ATE_pp_lo   = Csec_ATE_Lower95,
    ATE_pp_hi   = Csec_ATE_Upper95
  ) %>%
  select(Year, N, ATE_pp, ATE_pp_lo, ATE_pp_hi)

# ---- Baseline under-24-month mortality per wave (from METHODOLOGY_LOG.md
#       and PHASE_B_RESULTS_SUMMARY.md; these are the unconditional rates)
baseline <- tibble(
  Year = c("2004", "2011", "2017-2018", "2022"),
  p0   = c(0.0681, 0.0404, 0.0321, 0.0465)
)

ates <- left_join(ates, baseline, by = "Year") %>%
  mutate(
    # Convert risk-difference ATE → risk-ratio scale
    rr      = (p0 + ATE_pp) / p0,
    rr_lo   = (p0 + ATE_pp_lo) / p0,
    rr_hi   = (p0 + ATE_pp_hi) / p0,
    # Ensure RR > 1 for the formula; for protective effects, invert
    rr_use     = ifelse(rr < 1, 1 / rr,   rr),
    rr_use_lo  = pmin(ifelse(rr < 1, 1 / rr_hi, rr_lo),
                      ifelse(rr < 1, 1 / rr_lo, rr_hi)),
    rr_use_hi  = pmax(ifelse(rr < 1, 1 / rr_hi, rr_lo),
                      ifelse(rr < 1, 1 / rr_lo, rr_hi))
  )

cat("ATE → RR conversion:\n")
print(ates %>% select(Year, ATE_pp, p0, rr, rr_lo, rr_hi))
cat("\n")

# ---- Compute E-values
results <- ates %>%
  rowwise() %>%
  mutate(
    ev_point = {
      ev <- evalues.RR(est = rr_use, lo = rr_use_lo, hi = rr_use_hi, rare = FALSE)
      ev["E-values", "point"]
    },
    ev_ci = {
      ev <- evalues.RR(est = rr_use, lo = rr_use_lo, hi = rr_use_hi, rare = FALSE)
      # CI-based E-value: the worse (closer to 1) of the upper/lower CI E-values
      ci_low_ev  <- ev["E-values", "lower"]
      ci_high_ev <- ev["E-values", "upper"]
      # NA if CI crosses 1 (no E-value defined for null CI)
      if (is.na(ci_low_ev) && is.na(ci_high_ev)) NA_real_ else
        max(ci_low_ev, ci_high_ev, na.rm = TRUE)
    }
  ) %>%
  ungroup()

# ---- Save table
out_tbl <- results %>%
  select(Year, N, ATE_pp, p0, rr, ev_point, ev_ci) %>%
  mutate(
    interpretation = case_when(
      ev_point < 1.5 ~ "Fragile",
      ev_point < 2.0 ~ "Weak",
      ev_point < 3.0 ~ "Moderate",
      TRUE           ~ "Robust"
    )
  )
print(out_tbl)

out_csv <- here("outputs", "phase_d", "evalue_csection.csv")
write_csv(out_tbl, out_csv)
cat("\nSaved:", out_csv, "\n")

# ---- Figure
p <- ggplot(out_tbl, aes(x = Year, y = ev_point)) +
  geom_col(fill = "#c0392b", alpha = 0.85, width = 0.55) +
  geom_hline(yintercept = c(1.5, 2, 3), linetype = "dotted",
             color = c("#e67e22", "#16a085", "#2c3e50")) +
  annotate("text", x = 0.5, y = c(1.55, 2.05, 3.05),
           label = c("Fragile→", "Weak→", "Robust→"),
           hjust = 0, size = 3.2, color = c("#e67e22", "#16a085", "#2c3e50")) +
  geom_text(aes(label = sprintf("%.2f", ev_point)),
            vjust = -0.5, size = 4, fontface = "bold") +
  labs(
    title    = "E-values for C-section's effect on under-24-month mortality, by wave",
    subtitle = "VanderWeele & Ding (2017). 2022 (the only RBVP-significant wave) has the lowest E-value.",
    x = "DHS wave", y = "E-value (RR scale)",
    caption = "An E-value of X means an unmeasured confounder with risk ratio ≥ X for both treatment\nand outcome would nullify the observed association. Lower = more fragile."
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title    = element_text(face = "bold"),
    plot.subtitle = element_text(color = "gray30"),
    plot.caption  = element_text(color = "gray50", hjust = 0)
  )

out_png <- here("figures", "phase_d", "evalue_per_wave.png")
ggsave(out_png, p, width = 9, height = 6, dpi = 300)
cat("Saved:", out_png, "\n")

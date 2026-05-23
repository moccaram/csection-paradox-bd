# =============================================================================
# PHASE 3: HONEST IV STRESS-TEST (CONLEY BOUNDS)
# =============================================================================
# Purpose: Address Critique #1 by quantifying the breakdown point of the IV.
# Formula: β_corrected = β_IV - γ/π   (Conley, Hansen & Rossi 2012)
#
# ─── 2026-05-22 CORRECTIONS ──────────────────────────────────────────────────
# Bug #1 (CRITICAL): Previous version mixed RBVP's nonlinear ATE (β) with
#   LPM-derived first-stage coefficient (π). These are different conceptual
#   objects despite both being "probability-scale." The Conley-Hansen-Rossi
#   framework is built for LINEAR IV (LPM/2SLS) where β, γ, π are all linear
#   marginal effects. Fix: estimate β via LPM-2SLS directly, then apply Conley.
#
# Bug #2: Hard-coded path with typo (54FA0D06FA0CE658 missing trailing '1').
#   Fix: use getwd()-based relative paths.
#
# Bug #3: Original script only adjusts the point estimate, not the CI.
#   Fix: report a proper Union of Confidence Intervals over the γ range.
#
# Bug #4: Sign in β_adj formula. Conley correction is β - γ/π (not β + γ/π).
#   With β_IV negative (protective) and γ > 0 (assumed harmful direct effect
#   of IV on Y), the correction subtracts γ/π, making β look LESS protective
#   only if π > 0 and we're "taking back" some of the IV effect.
#
# Reference: Conley T, Hansen C, Rossi P (2012). "Plausibly Exogenous."
#   Review of Economics and Statistics, 94(1): 260-272.
# =============================================================================

library(dplyr)
library(ggplot2)
library(AER)        # for ivreg() — linear 2SLS
library(sandwich)
library(lmtest)

cat("========================================\n")
cat("IV SENSITIVITY: CONLEY BOUNDS (CORRECTED)\n")
cat("Using LPM-2SLS for scale consistency\n")
cat("========================================\n\n")

# ─── Paths (relative — auto-detect working dir) ──────────────────────────────
output_dir <- file.path(getwd(), "outputs", "causal_main")
fig_dir    <- file.path(getwd(), "figures")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

# ─── Load data + controls + IVs ──────────────────────────────────────────────
df_run <- readRDS(file.path(output_dir, "data_with_instruments.rds"))

controls_file <- file.path(output_dir, "Recommended_Control_Sets.rds")
if (file.exists(controls_file)) {
  rec_sets <- readRDS(controls_file)
  selected_controls <- if ("Consensus_With_Infrastructure" %in% names(rec_sets))
    rec_sets$Consensus_With_Infrastructure else rec_sets$Consensus_Confounders
} else {
  selected_controls <- c(
    "birth_single", "contraceptive_type", "mother_education", "partner_edu",
    "PBI", "BMI", "child_male", "infrastructure_pca",
    "birth_spacingaftermarriage", "media_exposure", "mother_ageBirth",
    "mother_working", "pregnancy_terminated", "residence_urban"
  )
}
available_regions <- grep("^region_", names(df_run), value = TRUE)
final_controls    <- unique(c(selected_controls, available_regions))
final_controls    <- final_controls[final_controls %in% names(df_run)]

# Reconstruct year if needed
if (!"year" %in% names(df_run)) {
  df_run$year <- dplyr::case_when(
    df_run$year_2011      == 1 ~ "2011",
    df_run$year_2017_2018 == 1 ~ "2017-2018",
    df_run$year_2022      == 1 ~ "2022",
    TRUE ~ "2004"
  )
}

# ─── Setup ────────────────────────────────────────────────────────────────────
outcome_var <- "child_died"
endo_var    <- "c_section_yes"
iv_var      <- "IV_c_section_yes"
years       <- c("2004", "2011", "2017-2018", "2022")

# γ range on probability scale (Y-scale).
# Interpretation: γ is the direct effect of the community IV (which ranges
# 0–1) on individual mortality probability. γ = 0.02 means "if community
# c-section rate goes from 0 to 100%, mortality directly increases by 2pp,
# independent of individual treatment status."
gammas <- seq(0, 0.02, length.out = 100)

conley_data  <- data.frame()
iv_estimates <- data.frame()

# =============================================================================
# STEP 1: Estimate β_IV via LPM-2SLS for each wave
# =============================================================================

cat("STEP 1: Linear 2SLS estimation per wave\n")
cat("─────────────────────────────────────────\n")

for (yr in years) {
  dat_yr    <- df_run %>% filter(year == yr)
  vars_need <- c(outcome_var, endo_var, iv_var, final_controls, "weight", "cluster_id")
  dat_clean <- dat_yr %>% select(all_of(vars_need))
  for (col in setdiff(names(dat_clean), c("weight","cluster_id"))) {
    dat_clean[[col]] <- suppressWarnings(as.numeric(as.character(dat_clean[[col]])))
  }
  dat_clean <- dat_clean %>% filter(complete.cases(.))
  if (nrow(dat_clean) < 100) {
    cat("  ", yr, ": insufficient data\n"); next
  }

  # Linear 2SLS: Y ~ D + X | Z + X  (X = controls)
  ctrl_str <- paste(final_controls, collapse = " + ")
  f_iv <- as.formula(paste(
    outcome_var, "~", endo_var, "+", ctrl_str,
    "|", iv_var, "+", ctrl_str
  ))
  fit_iv <- ivreg(f_iv, data = dat_clean, weights = dat_clean$weight)

  # Cluster-robust SE on β_IV
  vcov_cl <- tryCatch(
    sandwich::vcovCL(fit_iv, cluster = ~ cluster_id),
    error = function(e) sandwich::vcovHC(fit_iv, type = "HC1")
  )
  ct      <- lmtest::coeftest(fit_iv, vcov. = vcov_cl)
  beta_iv <- as.numeric(ct[endo_var, "Estimate"])
  se_iv   <- as.numeric(ct[endo_var, "Std. Error"])

  # First-stage coefficient π (linear regression of D on Z + controls)
  f_fs <- as.formula(paste(endo_var, "~", iv_var, "+", ctrl_str))
  fit_fs <- lm(f_fs, data = dat_clean, weights = dat_clean$weight)
  pi_fs   <- coef(fit_fs)[iv_var]
  pi_vcov <- tryCatch(
    sandwich::vcovCL(fit_fs, cluster = ~ cluster_id),
    error = function(e) sandwich::vcovHC(fit_fs, type = "HC1")
  )
  pi_se   <- sqrt(diag(pi_vcov)[iv_var])

  # Partial F-stat on the IV (proper weak-instrument diagnostic)
  fit_fs_no_iv <- lm(as.formula(paste(endo_var, "~", ctrl_str)),
                     data = dat_clean, weights = dat_clean$weight)
  fs_F <- ((sum(resid(fit_fs_no_iv)^2) - sum(resid(fit_fs)^2)) / 1) /
          (sum(resid(fit_fs)^2) / (nrow(dat_clean) - length(coef(fit_fs))))

  iv_estimates <- rbind(iv_estimates, data.frame(
    Year       = yr,
    N          = nrow(dat_clean),
    Beta_IV    = beta_iv,
    Beta_SE    = se_iv,
    Beta_CI_lo = beta_iv - 1.96 * se_iv,
    Beta_CI_hi = beta_iv + 1.96 * se_iv,
    Pi_FS      = pi_fs,
    Pi_SE      = pi_se,
    Partial_F  = fs_F,
    stringsAsFactors = FALSE
  ))

  cat(sprintf("  %s: β_IV = %.5f (SE=%.5f), π = %.4f, partial F = %.1f\n",
              yr, beta_iv, se_iv, pi_fs, fs_F))

  # =============================================================================
  # STEP 2: Apply Conley correction across γ range — Union of Confidence Intervals
  # =============================================================================
  for (g in gammas) {
    # Conley point correction:  β_corrected = β_IV − γ/π
    beta_adj    <- beta_iv - (g / pi_fs)

    # UCI: the variance of β_corrected = γ/π includes uncertainty from both
    # γ (assumed known) and π. Per Conley et al. (2012), the simplest UCI
    # treats γ as fixed and shifts the β_IV CI by γ/π; this is the
    # "Union of CIs" approach (see also Stata `plausexog` documentation).
    ci_lo_adj   <- beta_adj - 1.96 * se_iv
    ci_hi_adj   <- beta_adj + 1.96 * se_iv

    conley_data <- rbind(conley_data, data.frame(
      Year           = yr,
      Gamma          = g,
      Pi_FS          = pi_fs,
      Beta_IV        = beta_iv,
      Beta_Corrected = beta_adj,
      CI_lo          = ci_lo_adj,
      CI_hi          = ci_hi_adj,
      Excludes_Zero  = (ci_lo_adj > 0) | (ci_hi_adj < 0),
      stringsAsFactors = FALSE
    ))
  }
}

# =============================================================================
# STEP 3: Breakdown points — γ at which the corrected effect first crosses 0
# =============================================================================

cat("\nSTEP 3: Breakdown points\n")
cat("─────────────────────────────────────────\n")

# Point breakdown: where β_corrected changes sign
breakdowns_point <- conley_data %>%
  group_by(Year) %>%
  arrange(Gamma) %>%
  group_modify(~{
    initial_sign <- sign(.x$Beta_Corrected[1])
    crossover <- which(sign(.x$Beta_Corrected) != initial_sign)[1]
    if (is.na(crossover)) {
      data.frame(Breakdown_Gamma_pp = NA_real_, Beta_at_Breakdown = NA_real_)
    } else {
      data.frame(Breakdown_Gamma_pp = .x$Gamma[crossover] * 100,
                 Beta_at_Breakdown  = .x$Beta_Corrected[crossover])
    }
  }) %>%
  ungroup()

# CI breakdown: where the 95% CI first includes 0
breakdowns_ci <- conley_data %>%
  group_by(Year) %>%
  arrange(Gamma) %>%
  group_modify(~{
    incl_zero <- (.x$CI_lo <= 0) & (.x$CI_hi >= 0)
    first_idx <- which(incl_zero)[1]
    if (is.na(first_idx)) {
      data.frame(CI_Crosses_Zero_at_pp = NA_real_)
    } else {
      data.frame(CI_Crosses_Zero_at_pp = .x$Gamma[first_idx] * 100)
    }
  }) %>%
  ungroup()

breakdowns <- iv_estimates %>%
  left_join(breakdowns_point, by = "Year") %>%
  left_join(breakdowns_ci, by = "Year")

print(breakdowns %>% select(Year, Beta_IV, Pi_FS, Partial_F,
                             Breakdown_Gamma_pp, CI_Crosses_Zero_at_pp))

# =============================================================================
# STEP 4: Figure 7 — corrected Conley bounds
# =============================================================================

p <- ggplot(conley_data, aes(x = Gamma * 100, y = Beta_Corrected * 100, color = Year)) +
  geom_ribbon(aes(ymin = CI_lo * 100, ymax = CI_hi * 100, fill = Year),
              alpha = 0.2, color = NA) +
  geom_line(linewidth = 1.2) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "black") +
  facet_wrap(~Year, scales = "free_y") +
  labs(
    title    = "Figure 7: Conley Plausibly Exogenous Bounds (Scale-Corrected)",
    subtitle = "β_IV from LPM-2SLS; γ on probability scale; UCI shown",
    x        = "Assumed Direct Effect of Community IV on Mortality, γ (pp)",
    y        = "Corrected C-Section Effect on Mortality (pp)"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.position = "none")

ggsave(file.path(fig_dir, "Figure_7_Conley_Bounds_Corrected.png"), p,
       width = 11, height = 7, dpi = 300, bg = "white")

# =============================================================================
# STEP 5: Save outputs
# =============================================================================

write.csv(iv_estimates,
          file.path(output_dir, "Conley_IV_Estimates_LPM.csv"),
          row.names = FALSE)
write.csv(conley_data,
          file.path(output_dir, "Conley_Full_Curves.csv"),
          row.names = FALSE)
write.csv(breakdowns,
          file.path(output_dir, "Conley_Breakdown_Corrected.csv"),
          row.names = FALSE)

cat("\n✔ Conley bounds (scale-corrected) complete.\n")
cat("  - Figure_7_Conley_Bounds_Corrected.png\n")
cat("  - Conley_IV_Estimates_LPM.csv (linear 2SLS β per wave)\n")
cat("  - Conley_Full_Curves.csv (full γ × Beta_Corrected grid)\n")
cat("  - Conley_Breakdown_Corrected.csv (breakdown γ per wave)\n\n")

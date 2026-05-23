# =============================================================================
# 53_acerenza_inequalities.R — Phase D modern inference: simplified
# sample-analog test of the six testable inequalities from
# Acerenza, Bartalotti & Kédagni (2023).
#
# This is NOT the full Chernozhukov-Lee-Rosen machinery — it is a simplified
# R analog using sample analogs of Proposition 2's inequalities and
# bootstrapped percentile CIs. If any inequality's lower CI exceeds zero,
# the identifying assumptions of the bivariate probit are rejected.
#
# The 6 inequalities (for Y = child_died, D = c_section, Z = community LOO IV):
#   1.  sup_z E[YD       | Z=z] <=     Φ(β + α)
#   2.  sup_z E[Y(1-D)   | Z=z] <=     Φ(β)
#   3.  sup_z E[(1-Y)D   | Z=z] <= 1 - Φ(β + α)
#   4.  sup_z E[(1-Y)(1-D)|Z=z] <= 1 - Φ(β)
#   5.  inf_z E[Y       | Z=z]   >=   Φ(min(β+α, β))
#   6.  inf_z E[1-Y     | Z=z]   >= 1 - Φ(max(β+α, β))
#
# Input:  outputs/causal_main/data_with_instruments.rds
# Output: outputs/phase_d/acerenza_test_2022.csv
#         figures/phase_d/acerenza_violations.png
#
# Reference:
#   Acerenza S, Bartalotti O, Kédagni D (2023). Testing identifying
#   assumptions in bivariate probit models. Journal of Applied Econometrics
#   38(4):529-545.
# =============================================================================

suppressPackageStartupMessages({
  library(GJRM)
  library(boot)
  library(dplyr)
  library(ggplot2)
  library(readr)
  library(here)
})

set.seed(42)

# ---- Load 2022-wave data with instruments
df_full <- readRDS(here("outputs", "causal_main", "data_with_instruments.rds"))

# Filter to 2022 wave
df <- df_full %>% filter(year_2022 == 1)
cat("2022 wave N:", nrow(df), "\n")

# Identify instrument column for C-section (constructed in 41_rbvp_main.R)
z_col <- intersect(c("Z_csec", "z_csec", "iv_csec", "Z_iv"), names(df))[1]
if (is.na(z_col)) {
  # Fall back: compute leave-one-out cluster mean from c_section_yes
  cat("Z_csec not found; constructing leave-one-out cluster mean.\n")
  df <- df %>%
    group_by(cluster_id) %>%
    mutate(
      Z_iv = (sum(c_section_yes) - c_section_yes) / pmax(n() - 1, 1)
    ) %>%
    ungroup()
  z_col <- "Z_iv"
}
df$Z_iv <- df[[z_col]]

cat("Using IV column:", z_col, "\n")

# ---- Fit RBVP on 2022 wave to get β̂ (outcome eq intercept) and α̂ (treatment coef)
controls <- intersect(
  c("birth_single", "mother_education", "partner_edu",
    "media_exposure", "mother_working", "pregnancy_terminated"),
  names(df)
)

f1 <- as.formula(
  paste("child_died    ~ c_section_yes +", paste(controls, collapse = " + "))
)
f2 <- as.formula(
  paste("c_section_yes ~ Z_iv +",          paste(controls, collapse = " + "))
)

cat("Fitting RBVP on 2022 wave...\n")
fit <- tryCatch({
  GJRM::gjrm(
    formula = list(f1, f2),
    data    = df,
    model   = "B",
    margins = c("probit", "probit")
  )
}, error = function(e) { cat("RBVP fit error:", conditionMessage(e), "\n"); NULL })

if (is.null(fit)) stop("Cannot proceed without RBVP fit on 2022 wave.")

coefs <- coef(fit)
# β̂ is the outcome-equation intercept; α̂ is the treatment coefficient
beta_hat  <- coefs["(Intercept)"]
if (is.na(beta_hat)) beta_hat <- coefs[grep("eq1.\\(Intercept\\)", names(coefs), value = TRUE)[1]]
if (is.na(beta_hat)) beta_hat <- coefs[1]
alpha_hat <- coefs["c_section_yes"]
if (is.na(alpha_hat)) alpha_hat <- coefs[grep("c_section_yes", names(coefs), value = TRUE)[1]]

cat(sprintf("β̂ = %.4f, α̂ = %.4f\n", beta_hat, alpha_hat))

# ---- Bin Z into deciles
df$Z_bin <- cut(
  df$Z_iv,
  breaks = quantile(df$Z_iv, probs = seq(0, 1, 0.1), na.rm = TRUE),
  include.lowest = TRUE
)

# ---- Function computing sample analogs of the 6 inequalities
compute_inequalities <- function(data, beta, alpha) {
  data <- data %>%
    mutate(
      YD     = child_died * c_section_yes,
      Y1mD   = child_died * (1 - c_section_yes),
      mY_D   = (1 - child_died) * c_section_yes,
      mY_1mD = (1 - child_died) * (1 - c_section_yes)
    )
  g <- data %>%
    group_by(Z_bin) %>%
    summarise(
      E_YD     = mean(YD,     na.rm = TRUE),
      E_Y1mD   = mean(Y1mD,   na.rm = TRUE),
      E_mY_D   = mean(mY_D,   na.rm = TRUE),
      E_mY_1mD = mean(mY_1mD, na.rm = TRUE),
      E_Y      = mean(child_died, na.rm = TRUE),
      E_1mY    = mean(1 - child_died, na.rm = TRUE),
      .groups  = "drop"
    )

  rhs1 <- pnorm(beta + alpha)
  rhs2 <- pnorm(beta)
  rhs3 <- 1 - pnorm(beta + alpha)
  rhs4 <- 1 - pnorm(beta)
  rhs5 <- pnorm(min(beta + alpha, beta))
  rhs6 <- 1 - pnorm(max(beta + alpha, beta))

  c(
    ineq1 = max(g$E_YD,     na.rm = TRUE) - rhs1,
    ineq2 = max(g$E_Y1mD,   na.rm = TRUE) - rhs2,
    ineq3 = max(g$E_mY_D,   na.rm = TRUE) - rhs3,
    ineq4 = max(g$E_mY_1mD, na.rm = TRUE) - rhs4,
    ineq5 = rhs5 - min(g$E_Y,    na.rm = TRUE),
    ineq6 = rhs6 - min(g$E_1mY,  na.rm = TRUE)
  )
}

point_violations <- compute_inequalities(df, beta_hat, alpha_hat)
cat("\nPoint violations (positive = rejected):\n")
print(point_violations)

# ---- Bootstrap CIs (500 reps)
cat("\nBootstrapping 500 reps... (this takes ~1-2 min)\n")
boot_result <- boot(
  df,
  statistic = function(d, idx) compute_inequalities(d[idx, ], beta_hat, alpha_hat),
  R = 500
)

ci_list <- lapply(seq_len(6), function(i) {
  bc <- tryCatch(boot.ci(boot_result, index = i, type = "perc"),
                 error = function(e) NULL)
  if (is.null(bc)) c(NA, NA) else bc$percent[4:5]
})

results <- tibble(
  inequality     = paste0("ineq_", seq_len(6)),
  description    = c("sup E[YD|Z] ≤ Φ(β+α)",
                     "sup E[Y(1-D)|Z] ≤ Φ(β)",
                     "sup E[(1-Y)D|Z] ≤ 1-Φ(β+α)",
                     "sup E[(1-Y)(1-D)|Z] ≤ 1-Φ(β)",
                     "Φ(min) ≤ inf E[Y|Z]",
                     "1-Φ(max) ≤ inf E[1-Y|Z]"),
  point_violation = point_violations,
  ci_lower        = vapply(ci_list, function(x) x[1], numeric(1)),
  ci_upper        = vapply(ci_list, function(x) x[2], numeric(1)),
  rejected        = vapply(ci_list, function(x) !is.na(x[1]) && x[1] > 0, logical(1))
)

print(results)
out_csv <- here("outputs", "phase_d", "acerenza_test_2022.csv")
write_csv(results, out_csv)
cat("Saved:", out_csv, "\n")

# ---- Figure: forest plot of 6 inequality violations w/ CIs
results <- results %>%
  mutate(
    color  = ifelse(rejected, "Rejected (assumptions violated)", "Not rejected"),
    label  = sprintf("ineq %d", seq_len(6))
  )

p <- ggplot(results, aes(y = label, x = point_violation, color = color)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray30") +
  geom_errorbarh(aes(xmin = ci_lower, xmax = ci_upper), height = 0.2, linewidth = 0.8) +
  geom_point(size = 3.5) +
  geom_text(aes(x = ci_upper, label = description),
            hjust = -0.07, color = "gray20", size = 3, family = "mono") +
  scale_color_manual(values = c(`Rejected (assumptions violated)` = "#c0392b",
                                `Not rejected` = "#27ae60")) +
  scale_x_continuous(expand = expansion(mult = c(0.05, 0.6))) +
  labs(
    title    = "Acerenza, Bartalotti & Kédagni (2023): testable inequalities, 2022 wave",
    subtitle = "Positive value with lower CI > 0 → identifying assumptions violated",
    x = "Violation statistic (LHS − RHS, with bootstrap 95% CI)",
    y = NULL, color = NULL,
    caption = "Simplified R analog; N = 4671 (Bangladesh DHS 2022); 500 bootstrap replications."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position    = "top",
    plot.title         = element_text(face = "bold"),
    plot.subtitle      = element_text(color = "gray30"),
    plot.caption       = element_text(color = "gray50", hjust = 0)
  )

out_png <- here("figures", "phase_d", "acerenza_violations.png")
ggsave(out_png, p, width = 11, height = 6, dpi = 300)
cat("Saved:", out_png, "\n")

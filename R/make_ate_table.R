# =============================================================================
# make_ate_table.R — rendering helper for the headline wave-stratified ATE
# =============================================================================

#' Render the wave-stratified RBVP ATE summary as a kable table on the
#' percentage-point scale, with cluster-bootstrap CI.
#'
#' @param ate Data frame from `load_formal_ate()` containing columns
#'   Year, N, Csec_ATE, Csec_ATE_Lower95, Csec_ATE_Upper95
#'   (raw probability-scale; will be converted to percentage points here)
make_ate_table <- function(ate) {
  ate %>%
    dplyr::transmute(
      Wave           = Year,
      N              = formatC(N, big.mark = ",", format = "d"),
      `Csec ATE (pp)` = sprintf("%+.2f", 100 * Csec_ATE),
      `95% CI (pp)`   = fmt_ci_pp(100 * Csec_ATE_Lower95, 100 * Csec_ATE_Upper95),
      Significant    = ifelse(Csec_ATE_Upper95 < 0 | Csec_ATE_Lower95 > 0,
                              "**yes**", "no")
    ) %>%
    book_table(
      caption = "Wave-stratified RBVP ATE of C-section on under-24-month mortality, with cluster-bootstrap 95% confidence intervals.",
      align   = c("l", "r", "r", "c", "c")
    )
}

#' Render the 2SRI vs RBVP comparison table
make_2sri_table <- function(s2ri) {
  s2ri %>%
    dplyr::transmute(
      Wave            = Year,
      Treatment,
      `RBVP ATE (pp)` = sprintf("%+.2f", 100 * RBVP_ATE),
      `2SRI ATE (pp)` = sprintf("%+.2f", 100 * SRI_ATE),
      `Sign consistent` = ifelse(Sign_Consistent, "yes", "no"),
      `Resid p (endo test)` = fmt_p(Resid_P)
    ) %>%
    book_table(
      caption = "2SRI replication and Wooldridge-style endogeneity test. The residual coefficient's p-value tests for endogeneity in the C-section / ANC treatment.",
      align   = c("l", "l", "r", "r", "c", "r")
    )
}

#' Render the cross-instrument placebo table
make_placebo_table <- function(plac) {
  plac %>%
    dplyr::transmute(
      Wave        = Year,
      Placebo,
      Coefficient = sprintf("%+.2f", Coefficient),
      `p-value`   = fmt_p(P_value),
      Pass        = ifelse(Pass, "yes", "**no (fail)**")
    ) %>%
    book_table(
      caption = "Cross-instrument placebo test (Swanson & Hernán 2013). Every cell tests whether an instrument intended for one treatment also predicts the other treatment.",
      align   = c("l", "l", "r", "r", "c")
    )
}

#' Render the copula sign-flip robustness table
make_copula_table <- function(cop) {
  cop %>%
    dplyr::transmute(
      Wave             = Year,
      Treatment,
      `Gaussian (pp)`  = sprintf("%+.2f", 100 * ATE_Gaussian),
      `Frank (pp)`     = sprintf("%+.2f", 100 * ATE_Frank),
      `Clayton (pp)`   = sprintf("%+.2f", 100 * ATE_Clayton),
      `Signs consistent` = ifelse(Signs_Consistent, "yes", "**no (sign flip)**")
    ) %>%
    book_table(
      caption = "Copula sensitivity (McGovern et al. 2015; Klein et al. 2019). Sign-flip across Gaussian, Frank, and Clayton families indicates the bivariate-normality assumption is not robust.",
      align   = c("l", "l", "r", "r", "r", "c")
    )
}

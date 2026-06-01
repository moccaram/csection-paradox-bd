# =============================================================================
# load_data.R — canonical data loaders used by chapters
# =============================================================================

#' Load the Bangladesh causal-pipeline master input data
#'
#' Returns the cleaned, complete-cases data frame used as input to script
#' `41_rbvp_main.R` (after Step 1 cleaning). One row per child across the
#' four BDHS waves (2004, 2011, 2017–18, 2022).
load_master_data <- function() {
  readRDS(here::here("outputs", "causal_main", "data_step1_complete.rds"))
}

#' Load the formal RBVP ATE results
load_formal_ate <- function() {
  readr::read_csv(
    here::here("outputs", "causal_main", "Formal_ATE_Results.csv"),
    show_col_types = FALSE
  )
}

#' Load the 2SRI Wooldridge-style summary comparison
load_2sri_summary <- function() {
  readr::read_csv(
    here::here("outputs", "causal_main", "2SRI_Summary_Comparison.csv"),
    show_col_types = FALSE
  )
}

#' Load the cross-instrument placebo table
load_iv_placebo <- function() {
  readr::read_csv(
    here::here("outputs", "causal_main", "IV_Placebo_Tests.csv"),
    show_col_types = FALSE
  )
}

#' Load the copula sign-flip robustness table
load_copula_signflip <- function() {
  readr::read_csv(
    here::here("outputs", "causal_main", "Copula_SignFlip_Check.csv"),
    show_col_types = FALSE
  )
}

#' Load the Conley plausibly-exogenous LPM-2SLS estimates
load_conley_estimates <- function() {
  readr::read_csv(
    here::here("outputs", "causal_main", "Conley_IV_Estimates_LPM.csv"),
    show_col_types = FALSE
  )
}

#' Load the first-stage IV diagnostics
load_first_stage <- function() {
  readr::read_csv(
    here::here("outputs", "causal_main", "FirstStage_Diagnostics.csv"),
    show_col_types = FALSE
  )
}

#' Load Phase D — E-value
load_evalue <- function() {
  readr::read_csv(
    here::here("outputs", "phase_d", "evalue_csection.csv"),
    show_col_types = FALSE
  )
}

#' Load Phase D — sensemakr summary
load_sensemakr <- function() {
  readr::read_csv(
    here::here("outputs", "phase_d", "sensemakr_summary.csv"),
    show_col_types = FALSE
  )
}

#' Load Phase D — Acerenza six-inequality test
load_acerenza <- function() {
  readr::read_csv(
    here::here("outputs", "phase_d", "acerenza_test_2022.csv"),
    show_col_types = FALSE
  )
}

#' Load Phase D — Chow break-test summary
load_chow <- function() {
  readr::read_csv(
    here::here("outputs", "phase_d", "chow_test_2011.csv"),
    show_col_types = FALSE
  )
}

#' Load descriptive trajectories (South Asia, multi-country)
load_csec_trends <- function() {
  readr::read_csv(
    here::here("data", "processed", "descriptive", "P1_Csec_Trends_All.csv"),
    show_col_types = FALSE
  )
}

#' Load descriptive sample characteristics by wave
load_sample_chars <- function() {
  readr::read_csv(
    here::here("data", "processed", "descriptive", "Sample_Characteristics.csv"),
    show_col_types = FALSE
  )
}

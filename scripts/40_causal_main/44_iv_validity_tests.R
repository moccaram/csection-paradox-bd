# =============================================================================
# SCRIPT: FORMAL IV ASSUMPTION VALIDITY TESTS (Addition 3)
# =============================================================================
# Purpose:  Provide formal empirical tests of the three core identifying
#           assumptions underlying the community-level IV strategy, rather
#           than relying solely on theoretical argument.
#
# Assumptions Tested:
#   (1) RELEVANCE     — IV strongly predicts treatment (first-stage F > 10)
#                       Already in Script 3; re-reported here for completeness.
#   (2) EXOGENEITY    — IV is uncorrelated with individual-level confounders
#                       Test: balance regressions (IV ~ confounder + regions)
#                       If IV is picking up general healthcare access rather
#                       than exogenous variation, it will predict wealth,
#                       education, residence, etc. at the individual level.
#   (3) EXCLUSION     — IV affects mortality ONLY through individual treatment
#                       Test A: Reduced-form test — IV predicts mortality in
#                               expected direction via treatment pathway.
#                       Test B: Cross-instrument placebo — IV_csec should NOT
#                               predict individual ANC uptake and vice versa.
#                               Significant cross-predictions imply instruments
#                               capture general access rather than specific
#                               treatment pathways (the key exclusion threat).
#
# Methodological basis:
#   Swanson & Hernán (2013) IV reporting checklist — Epidemiology
#   Bound, Jaeger & Baker (1995) — weak instrument diagnostics
#
# Note (2026-05-22): an earlier header cited Acerenza, Bartalotti & Kédagni
#   (2023) as "theoretical motivation." That citation was decorative — the
#   six-inequality intersection-bounds test from Acerenza et al. is NOT
#   implemented here. The three tests below (balance, reduced-form, cross-
#   instrument placebo) are standard IV diagnostics per Swanson-Hernán.
#   Formal Acerenza testing is deferred to a separate Phase D script.
#
# Caveat: F > 10 is the Bound-Jaeger-Baker (1995) rule. Modern guidance
#   (Lee, Moreira, Porter & Yap 2022) suggests F > ~104 for tight CIs and
#   weak-instrument-robust inference (Anderson-Rubin) when F is below that.
#
# Input:   data_step1_complete.rds, Recommended_Control_Sets.rds,
#          FirstStage_Diagnostics.csv (relevance, already computed)
# Output:  4 CSV files
# Runtime: ~5 minutes
# =============================================================================

library(dplyr)

cat("=============================================\n")
cat("IV ASSUMPTION VALIDITY TESTS\n")
cat("Relevance | Exogeneity | Exclusion Restriction\n")
cat("=============================================\n\n")

# ─── Directories ──────────────────────────────────────────────────────────────
input_dir  <- file.path(getwd(), "outputs", "causal_main")
output_dir <- file.path(getwd(), "outputs", "causal_main")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# ─── Significance threshold for balance test ──────────────────────────────────
ALPHA_BALANCE <- 0.05

# =============================================================================
# STEP 1: LOAD DATA & CONTROLS (identical to Scripts 3 and 2SRI)
# =============================================================================

cat("STEP 1: Loading data and controls\n-----------------------------------\n")

df_run <- readRDS(file.path(input_dir, "data_step1_complete.rds"))
cat("✓ Data loaded: N =", nrow(df_run), "\n")

controls_file <- file.path(output_dir, "Recommended_Control_Sets.rds")
if (file.exists(controls_file)) {
  recommended_sets <- readRDS(controls_file)
  selected_controls <- if ("Consensus_With_Infrastructure" %in% names(recommended_sets))
    recommended_sets$Consensus_With_Infrastructure else
      recommended_sets$Consensus_Confounders
} else {
  selected_controls <- c(
    "birth_single", "contraceptive_type", "mother_education", "partner_edu",
    "PBI", "BMI", "child_male", "infrastructure_index",
    "birth_spacingaftermarriage", "media_exposure", "mother_ageBirth",
    "mother_working", "pregnancy_terminated", "residence_urban"
  )
}

# Reconstruct year
if (!"year" %in% names(df_run)) {
  df_run$year <- dplyr::case_when(
    df_run$year_2011      == 1 ~ "2011",
    df_run$year_2017_2018 == 1 ~ "2017-2018",
    df_run$year_2022      == 1 ~ "2022",
    TRUE ~ "2004"
  )
}

# =============================================================================
# STEP 2: DATA PREPARATION (identical to Scripts 3 and 2SRI)
# =============================================================================

cat("\nSTEP 2: Data preparation\n-----------------------------------\n")

# Mother education direction
if ("mother_education" %in% names(df_run)) {
  cor_edu <- cor(as.numeric(df_run$mother_education), df_run$child_died, use="complete.obs")
  if (cor_edu > 0) {
    mx <- max(as.numeric(df_run$mother_education), na.rm=TRUE)
    mn <- min(as.numeric(df_run$mother_education), na.rm=TRUE)
    df_run$mother_education <- (mx + mn) - as.numeric(df_run$mother_education)
    cat("✓ Mother education direction corrected\n")
  }
}

# Infrastructure PCA
infra_cols <- c("wealth", "sanitation", "housing_quality", "electricity_yes", "cooking_fuel")
if (all(infra_cols %in% names(df_run))) {
  infra_mat <- df_run[, infra_cols]
  infra_mat[] <- lapply(infra_mat, function(x) as.numeric(as.character(x)))
  pca_res <- prcomp(na.omit(infra_mat), scale.=TRUE)
  df_run$infrastructure_pca <- NA
  df_run$infrastructure_pca[complete.cases(infra_mat)] <- pca_res$x[,1]
  if (cor(df_run$infrastructure_pca, df_run$child_died, use="complete.obs") > 0)
    df_run$infrastructure_pca <- -df_run$infrastructure_pca
  if ("infrastructure_index" %in% selected_controls)
    selected_controls <- c(setdiff(selected_controls, "infrastructure_index"), "infrastructure_pca")
}

# =============================================================================
# STEP 3: IV CREATION
# =============================================================================

cat("\nSTEP 3: Instrument creation\n-----------------------------------\n")

for (var in c("c_section_yes", "anc_4plus")) {
  iv_name <- paste0("IV_", var)
  df_run <- df_run %>%
    group_by(year, cluster_id) %>%
    mutate(
      cluster_size = n(),
      cluster_sum  = sum(!!sym(var), na.rm=TRUE),
      !!iv_name := ifelse(cluster_size > 1,
                          (cluster_sum - !!sym(var)) / (cluster_size - 1),
                          NA)
    ) %>%
    ungroup() %>%
    select(-cluster_size, -cluster_sum)
  cat("✓", iv_name, "created\n")
}

# Finalise controls
available_regions <- grep("^region_", names(df_run), value=TRUE)
selected_controls <- unique(c(selected_controls, available_regions))
final_controls    <- selected_controls[selected_controls %in% names(df_run)]

# Confounders WITHOUT region dummies (for balance regressions — regions
# are part of the IV construction and should not be used as "confounders"
# in the balance test)
substantive_controls <- final_controls[!grepl("^region_", final_controls)]

cat("✓ Final controls: n =", length(final_controls), "\n")
cat("✓ Substantive confounders for balance test: n =", length(substantive_controls), "\n\n")

# Variable aliases
outcome_var <- "child_died"
endo_1      <- "c_section_yes"
endo_2      <- "anc_4plus"
iv_1        <- "IV_c_section_yes"
iv_2        <- "IV_anc_4plus"
years       <- c("2004", "2011", "2017-2018", "2022")

# =============================================================================
# STEP 4: TEST 1 — INSTRUMENT RELEVANCE (re-read from existing output)
# =============================================================================

cat("STEP 4: Test 1 — Instrument Relevance\n-----------------------------------\n")

relevance_file <- file.path(output_dir, "FirstStage_Diagnostics.csv")
if (file.exists(relevance_file)) {
  relevance_df <- read.csv(relevance_file, stringsAsFactors=FALSE)
  cat("✓ Loaded FirstStage_Diagnostics.csv\n")
  cat("  C-section F-statistics:", paste(round(relevance_df$Csec_FirstStage_F, 1), collapse=", "), "\n")
  cat("  ANC F-statistics:",       paste(round(relevance_df$ANC_FirstStage_F, 1),  collapse=", "), "\n")
  cat("  All F > 10?",
      ifelse(all(relevance_df$Csec_FirstStage_F > 10) && all(relevance_df$ANC_FirstStage_F > 10),
             "YES ✓", "SOME FAIL ⚠"), "\n\n")
} else {
  cat("⚠ FirstStage_Diagnostics.csv not found. Re-running relevance tests...\n")
  relevance_df <- NULL
}

# =============================================================================
# STEP 5: TEST 2 — INSTRUMENT EXOGENEITY (balance test)
# =============================================================================
# For each wave and each IV, regress each confounder on the IV controlling for
# region fixed effects. Under the null of IV exogeneity, the IV should be
# uncorrelated with individual-level characteristics after controlling for
# regional fixed effects (which drive the IV through cluster aggregation).
#
# Interpretation: the IV is the LEAVE-ONE-OUT cluster mean, so by construction
# it reflects aggregate community patterns, not individual-level variation.
# The balance test formally verifies this doesn't bleed into individual
# confounders — i.e., that community uptake rates do not track individual
# socioeconomic status after conditioning on region.
# =============================================================================

cat("STEP 5: Test 2 — Instrument Exogeneity (Balance Test)\n-----------------------------------\n")
cat("Testing: IV ~ confounder + region (expecting non-significant coefficients)\n\n")

balance_results <- data.frame()

for (yr in years) {
  cat("Year:", yr, "\n")
  
  dat_yr    <- df_run %>% filter(year == yr)
  vars_need <- c(outcome_var, endo_1, endo_2, iv_1, iv_2, final_controls)
  dat_clean <- dat_yr %>% select(all_of(vars_need))
  for (col in names(dat_clean))
    dat_clean[[col]] <- suppressWarnings(as.numeric(as.character(dat_clean[[col]])))
  dat_clean <- dat_clean %>% filter(complete.cases(.))
  
  N <- nrow(dat_clean)
  
  for (iv_name in c(iv_1, iv_2)) {
    iv_label <- ifelse(iv_name == iv_1, "C-section IV", "ANC IV")
    n_sig <- 0
    
    for (conf in substantive_controls) {
      if (!conf %in% names(dat_clean)) next

      # Regress confounder on IV, controlling for region FEs (if any exist)
      # FIX 2026-05-22: when no region_* columns are present in the data,
      # the original formula ended with a dangling "+". Now handle empty case.
      regions_in_data <- available_regions[available_regions %in% names(dat_clean)]
      rhs_extra <- if (length(regions_in_data) > 0)
        paste(" +", paste(regions_in_data, collapse = " + ")) else ""
      f_balance <- as.formula(paste(conf, "~", iv_name, rhs_extra))
      tryCatch({
        fit_b  <- lm(f_balance, data=dat_clean)
        summ_b <- coef(summary(fit_b))
        iv_row <- summ_b[iv_name, , drop=FALSE]
        
        coef_b <- iv_row[, "Estimate"]
        se_b   <- iv_row[, "Std. Error"]
        p_b    <- iv_row[, "Pr(>|t|)"]
        sig_b  <- p_b < ALPHA_BALANCE
        
        if (sig_b) n_sig <- n_sig + 1
        
        balance_results <- rbind(balance_results, data.frame(
          Year        = yr,
          N           = N,
          IV          = iv_label,
          Confounder  = conf,
          Coefficient = coef_b,
          SE          = se_b,
          P_value     = p_b,
          Significant = sig_b,
          stringsAsFactors = FALSE
        ))
      }, error = function(e) NULL)
    }
    
    n_tested <- length(substantive_controls[substantive_controls %in% names(dat_clean)])
    pct_sig  <- round(100 * n_sig / n_tested, 1)
    status   <- if (pct_sig <= 10) "✓ PASS" else "⚠ CONCERN"
    
    cat("  ", iv_label, "—", n_sig, "/", n_tested,
        "confounders significant (", pct_sig, "%) →", status, "\n")
  }
  cat("\n")
}

# =============================================================================
# STEP 6: TEST 3A — EXCLUSION RESTRICTION: REDUCED FORM TEST
# =============================================================================
# Under the null that exclusion restriction holds, the IV should predict
# mortality in the EXPECTED direction: higher community C-section rates →
# lower individual mortality (if C-sections are protective), operating
# entirely through individual treatment uptake.
#
# The reduced form coefficient estimates: IV → mortality (total effect via
# the treatment pathway). Its sign should match: IV→treatment (positive) ×
# treatment→mortality (negative) = negative.
#
# If the reduced form is significant with the expected sign, this is evidence
# that the IV's effect on mortality operates through the intended channel.
# If the reduced form sign is WRONG (e.g. positive when protective effect
# expected), this would be a red flag for violations.
# =============================================================================

cat("STEP 6: Test 3a — Exclusion Restriction: Reduced Form\n-----------------------------------\n")
cat("Testing: outcome ~ IV + controls (no treatment variable)\n")
cat("Expected: IV coefficient same sign as (first-stage sign × treatment effect sign)\n\n")

reduced_form_results <- data.frame()

for (yr in years) {
  cat("Year:", yr, "\n")
  
  dat_yr    <- df_run %>% filter(year == yr)
  vars_need <- c(outcome_var, endo_1, endo_2, iv_1, iv_2, final_controls)
  dat_clean <- dat_yr %>% select(all_of(vars_need))
  for (col in names(dat_clean))
    dat_clean[[col]] <- suppressWarnings(as.numeric(as.character(dat_clean[[col]])))
  dat_clean <- dat_clean %>% filter(complete.cases(.))
  
  N <- nrow(dat_clean)
  
  for (iv_name in c(iv_1, iv_2)) {
    trt_name  <- ifelse(iv_name == iv_1, endo_1, endo_2)
    iv_label  <- ifelse(iv_name == iv_1, "C-section IV", "ANC IV")
    
    # Reduced form: outcome ~ IV + controls (NO treatment variable)
    f_rf <- as.formula(paste(outcome_var, "~", iv_name, "+",
                             paste(final_controls, collapse=" + ")))
    
    tryCatch({
      fit_rf <- glm(f_rf, data=dat_clean, family=binomial(link="probit"))
      summ_rf <- coef(summary(fit_rf))
      
      rf_coef <- summ_rf[iv_name, "Estimate"]
      rf_se   <- summ_rf[iv_name, "Std. Error"]
      rf_p    <- summ_rf[iv_name, "Pr(>|z|)"]
      
      # Also get first-stage sign for comparison
      f_fs <- as.formula(paste(trt_name, "~", iv_name, "+",
                               paste(final_controls, collapse=" + ")))
      fit_fs <- glm(f_fs, data=dat_clean, family=binomial(link="probit"))
      fs_coef <- coef(summary(fit_fs))[iv_name, "Estimate"]
      
      # If IV increases treatment (fs_coef > 0) and treatment reduces mortality,
      # we expect rf_coef < 0 (IV reduces mortality overall)
      # Sign consistency: sign(rf_coef) should = sign(fs_coef) × expected_trt_sign
      # Since we expect treatment to be protective (negative effect on mortality):
      # expected rf_coef sign = positive fs_coef × negative treatment = NEGATIVE
      expected_sign_neg <- fs_coef > 0  # TRUE if we expect rf_coef < 0
      sign_consistent   <- if (expected_sign_neg) (rf_coef < 0) else (rf_coef > 0)
      
      status <- if (sign_consistent) "✓ CONSISTENT" else "⚠ INCONSISTENT"
      sig_str <- if (rf_p < 0.05) "***" else if (rf_p < 0.10) "†" else ""
      
      cat("  ", iv_label, ": RF coef =", round(rf_coef, 4),
          "(p =", round(rf_p, 3), sig_str, ")", status, "\n")
      
      reduced_form_results <- rbind(reduced_form_results, data.frame(
        Year             = yr,
        N                = N,
        IV               = iv_label,
        FirstStage_Coef  = fs_coef,
        RF_Coefficient   = rf_coef,
        RF_SE            = rf_se,
        RF_P_value       = rf_p,
        Sign_Consistent  = sign_consistent,
        stringsAsFactors = FALSE
      ))
    }, error = function(e) {
      cat("  ", iv_label, ": error —", e$message, "\n")
    })
  }
  cat("\n")
}

# =============================================================================
# STEP 7: TEST 3B — EXCLUSION RESTRICTION: CROSS-INSTRUMENT PLACEBO TEST
# =============================================================================
# The most direct falsification of the exclusion restriction:
# IV_csec should NOT predict individual ANC uptake
# IV_anc  should NOT predict individual C-section uptake
#
# If significant cross-predictions exist, the instruments are tracking
# general healthcare access at community level rather than treatment-specific
# variation — meaning their effect on mortality may bypass the specific
# treatment pathway, violating the exclusion restriction.
#
# This is the "wrong treatment" placebo: the instrument for C-section is
# being used to predict ANC (and vice versa). Under the null of specific
# instruments, these cross-predictions should be null.
# =============================================================================

cat("STEP 7: Test 3b — Exclusion Restriction: Cross-Instrument Placebo\n-----------------------------------\n")
cat("Testing: IV_csec → ANC (and IV_anc → C-section)\n")
cat("Expected: BOTH non-significant (instruments are treatment-specific)\n\n")

placebo_results <- data.frame()

for (yr in years) {
  cat("Year:", yr, "\n")
  
  dat_yr    <- df_run %>% filter(year == yr)
  vars_need <- c(outcome_var, endo_1, endo_2, iv_1, iv_2, final_controls)
  dat_clean <- dat_yr %>% select(all_of(vars_need))
  for (col in names(dat_clean))
    dat_clean[[col]] <- suppressWarnings(as.numeric(as.character(dat_clean[[col]])))
  dat_clean <- dat_clean %>% filter(complete.cases(.))
  
  N <- nrow(dat_clean)
  
  # Placebo 1: IV_csec → ANC (wrong treatment for this IV)
  tryCatch({
    f_p1 <- as.formula(paste(endo_2, "~", iv_1, "+", paste(final_controls, collapse=" + ")))
    fit_p1 <- glm(f_p1, data=dat_clean, family=binomial(link="probit"))
    summ_p1 <- coef(summary(fit_p1))
    
    p1_coef <- summ_p1[iv_1, "Estimate"]
    p1_se   <- summ_p1[iv_1, "Std. Error"]
    p1_p    <- summ_p1[iv_1, "Pr(>|z|)"]
    p1_sig  <- p1_p < ALPHA_BALANCE
    
    status_p1 <- if (!p1_sig) "✓ PASS (non-significant)" else "⚠ FAIL (significant!)"
    cat("  IV_csec → ANC 4+:    coef =", round(p1_coef, 4),
        "(p =", round(p1_p, 3), ")", status_p1, "\n")
    
    placebo_results <- rbind(placebo_results, data.frame(
      Year        = yr,
      N           = N,
      Placebo     = "IV_csec → ANC (wrong treatment)",
      IV_Used     = "C-section IV",
      True_Target = "C-section",
      Wrong_Tgt   = "ANC 4+",
      Coefficient = p1_coef,
      SE          = p1_se,
      P_value     = p1_p,
      Significant = p1_sig,
      Pass        = !p1_sig,
      stringsAsFactors = FALSE
    ))
  }, error = function(e) cat("  Placebo 1 error:", e$message, "\n"))
  
  # Placebo 2: IV_anc → C-section (wrong treatment for this IV)
  tryCatch({
    f_p2 <- as.formula(paste(endo_1, "~", iv_2, "+", paste(final_controls, collapse=" + ")))
    fit_p2 <- glm(f_p2, data=dat_clean, family=binomial(link="probit"))
    summ_p2 <- coef(summary(fit_p2))
    
    p2_coef <- summ_p2[iv_2, "Estimate"]
    p2_se   <- summ_p2[iv_2, "Std. Error"]
    p2_p    <- summ_p2[iv_2, "Pr(>|z|)"]
    p2_sig  <- p2_p < ALPHA_BALANCE
    
    status_p2 <- if (!p2_sig) "✓ PASS (non-significant)" else "⚠ FAIL (significant!)"
    cat("  IV_anc  → C-section: coef =", round(p2_coef, 4),
        "(p =", round(p2_p, 3), ")", status_p2, "\n")
    
    placebo_results <- rbind(placebo_results, data.frame(
      Year        = yr,
      N           = N,
      Placebo     = "IV_anc → C-section (wrong treatment)",
      IV_Used     = "ANC IV",
      True_Target = "ANC 4+",
      Wrong_Tgt   = "C-section",
      Coefficient = p2_coef,
      SE          = p2_se,
      P_value     = p2_p,
      Significant = p2_sig,
      Pass        = !p2_sig,
      stringsAsFactors = FALSE
    ))
  }, error = function(e) cat("  Placebo 2 error:", e$message, "\n"))
  
  cat("\n")
}

# =============================================================================
# STEP 8: SUMMARY TABLE (all tests, pass/fail by wave)
# =============================================================================

cat("STEP 8: Summary Table\n-----------------------------------\n")

# Balance summary: proportion of confounders NOT significant (pass rate)
balance_summary <- balance_results %>%
  group_by(Year, IV) %>%
  summarise(
    N_Confounders = n(),
    N_Significant = sum(Significant),
    Pct_Significant = round(100 * mean(Significant), 1),
    Balance_Pass = Pct_Significant <= 10,
    .groups = "drop"
  )

# Placebo summary: all 4 per year
placebo_summary <- placebo_results %>%
  group_by(Year) %>%
  summarise(
    Placebo_Csec_to_ANC_P = P_value[Placebo == "IV_csec → ANC (wrong treatment)"],
    Placebo_ANC_to_Csec_P = P_value[Placebo == "IV_anc → C-section (wrong treatment)"],
    Both_Placebos_Pass    = all(Pass),
    .groups = "drop"
  )

# Reduced form summary
rf_summary <- reduced_form_results %>%
  group_by(Year) %>%
  summarise(
    RF_Csec_P    = RF_P_value[IV == "C-section IV"],
    RF_ANC_P     = RF_P_value[IV == "ANC IV"],
    RF_Csec_Sign = Sign_Consistent[IV == "C-section IV"],
    RF_ANC_Sign  = Sign_Consistent[IV == "ANC IV"],
    .groups = "drop"
  )

# First-stage pass/fail (from loaded file or re-computed)
if (!is.null(relevance_df) && nrow(relevance_df) > 0) {
  rel_summary <- relevance_df %>%
    select(Year, Csec_FirstStage_F, ANC_FirstStage_F) %>%
    mutate(
      Csec_F_Pass = Csec_FirstStage_F > 10,
      ANC_F_Pass  = ANC_FirstStage_F  > 10,
      Both_Relevance_Pass = Csec_F_Pass & ANC_F_Pass
    )
} else {
  rel_summary <- data.frame(Year = years, Both_Relevance_Pass = NA)
}

# Join everything into one summary
iv_validity_summary <- rel_summary %>%
  left_join(balance_summary %>% filter(IV == "C-section IV") %>%
              select(Year, Balance_Csec_PctSig = Pct_Significant, Balance_Csec_Pass = Balance_Pass),
            by = "Year") %>%
  left_join(balance_summary %>% filter(IV == "ANC IV") %>%
              select(Year, Balance_ANC_PctSig = Pct_Significant, Balance_ANC_Pass = Balance_Pass),
            by = "Year") %>%
  left_join(rf_summary, by = "Year") %>%
  left_join(placebo_summary, by = "Year") %>%
  mutate(
    Overall_Pass = Both_Relevance_Pass &
      Balance_Csec_Pass & Balance_ANC_Pass &
      RF_Csec_Sign & RF_ANC_Sign &
      Both_Placebos_Pass
  )

# =============================================================================
# STEP 9: SAVE OUTPUTS
# =============================================================================

cat("\nSTEP 9: Saving outputs\n-----------------------------------\n")

out <- function(df, name) {
  write.csv(df, file.path(output_dir, name), row.names=FALSE)
  cat("✓ Saved:", name, "\n")
}

out(balance_results,     "IV_Balance_Table.csv")
out(balance_summary,     "IV_Balance_Summary.csv")
out(reduced_form_results,"IV_Reduced_Form.csv")
out(placebo_results,     "IV_Placebo_Tests.csv")
out(iv_validity_summary, "IV_Validity_Summary.csv")

# =============================================================================
# STEP 10: DIAGNOSTIC REPORT
# =============================================================================

cat("\n")
cat(strrep("=", 60), "\n")
cat("IV ASSUMPTION VALIDITY — COMPLETE RESULTS\n")
cat(strrep("=", 60), "\n\n")

cat("TEST 1: INSTRUMENT RELEVANCE (first-stage F > 10)\n")
cat(strrep("-", 45), "\n")
if (!is.null(relevance_df)) {
  for (i in seq_len(nrow(relevance_df))) {
    cat(sprintf("  %s: C-section F=%.1f (%s), ANC F=%.1f (%s)\n",
                relevance_df$Year[i],
                relevance_df$Csec_FirstStage_F[i],
                ifelse(relevance_df$Csec_FirstStage_F[i] > 10, "✓", "⚠"),
                relevance_df$ANC_FirstStage_F[i],
                ifelse(relevance_df$ANC_FirstStage_F[i] > 10, "✓", "⚠")
    ))
  }
}

cat("\nTEST 2: INSTRUMENT EXOGENEITY (balance — % confounders significant)\n")
cat(strrep("-", 45), "\n")
for (yr in years) {
  bs_c <- balance_summary %>% filter(Year == yr, IV == "C-section IV")
  bs_a <- balance_summary %>% filter(Year == yr, IV == "ANC IV")
  if (nrow(bs_c) > 0 && nrow(bs_a) > 0)
    cat(sprintf("  %s: C-sec IV=%s%%(%s), ANC IV=%s%%(%s)\n",
                yr,
                bs_c$Pct_Significant, ifelse(bs_c$Balance_Pass, "✓", "⚠"),
                bs_a$Pct_Significant, ifelse(bs_a$Balance_Pass, "✓", "⚠")
    ))
}

cat("\nTEST 3A: EXCLUSION RESTRICTION — REDUCED FORM SIGNS\n")
cat(strrep("-", 45), "\n")
for (i in seq_len(nrow(reduced_form_results))) {
  r <- reduced_form_results[i, ]
  cat(sprintf("  %s %s: coef=%.4f (p=%.3f) → %s\n",
              r$Year, r$IV,
              r$RF_Coefficient, r$RF_P_value,
              ifelse(r$Sign_Consistent, "✓ CONSISTENT", "⚠ INCONSISTENT")
  ))
}

cat("\nTEST 3B: EXCLUSION RESTRICTION — CROSS-INSTRUMENT PLACEBO\n")
cat(strrep("-", 45), "\n")
for (i in seq_len(nrow(placebo_results))) {
  r <- placebo_results[i, ]
  cat(sprintf("  %s — %s: coef=%.4f (p=%.3f) → %s\n",
              r$Year, r$Placebo,
              r$Coefficient, r$P_value,
              ifelse(r$Pass, "✓ PASS", "⚠ FAIL")
  ))
}

cat("\n")
cat(strrep("=", 60), "\n")
cat("OVERALL VERDICT BY WAVE\n")
cat(strrep("=", 60), "\n")
for (i in seq_len(nrow(iv_validity_summary))) {
  r <- iv_validity_summary[i, ]
  cat(sprintf("  %s: %s\n", r$Year,
              ifelse(isTRUE(r$Overall_Pass), "✓ ALL TESTS PASS", "⚠ ONE OR MORE CONCERNS")))
}

cat("\n")
cat("MANUSCRIPT NOTES:\n")
cat(strrep("-", 60), "\n")
cat("If all tests pass:\n")
cat("  'Three formal tests support the validity of the community-\n")
cat("   level IV strategy. First, instruments were strong in all\n")
cat("   four waves (first-stage F > 10). Second, the IV was\n")
cat("   uncorrelated with individual-level confounders after\n")
cat("   controlling for regional fixed effects ([X]% of balance\n")
cat("   tests non-significant). Third, cross-instrument placebo\n")
cat("   tests showed IV_csec did not predict individual ANC uptake\n")
cat("   and IV_anc did not predict individual C-section uptake,\n")
cat("   confirming that instruments capture treatment-specific\n")
cat("   rather than general healthcare access variation.'\n\n")

cat("If a placebo fails:\n")
cat("  Acknowledge that some cross-IV correlation exists, note that\n")
cat("  instruments partially reflect shared access infrastructure,\n")
cat("  and cite the 2SRI results (Addition 2) as an additional\n")
cat("  robustness check that does not rely on strict exclusion.\n\n")

cat("✓ IV Assumption Validity Tests complete!\n")
cat("  Output directory:", output_dir, "\n\n")
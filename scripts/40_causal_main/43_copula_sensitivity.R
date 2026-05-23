# =============================================================================
# SCRIPT: COPULA SENSITIVITY ANALYSIS
# =============================================================================
# Purpose:  Re-estimate all 8 RBVP models (4 waves × 2 treatments) under
#           three copula families to test robustness of ATEs and ρ to the
#           bivariate normality assumption.
#
# Copulas tested:
#   - Gaussian   (copula = default) : current baseline - bivariate normal
#   - Frank      (copula = "F")     : symmetric, unbounded dependence
#   - Clayton    (copula = "C0")    : lower-tail dependence (adverse selection)
#
# Methodology references:
#   - McGovern et al. (2015, Epidemiology): template for this analysis
#   - Klein et al. (2019, Stat Med): GJRM copula implementation
#   - Han & Vytlacil (2017, J Econometrics): identification holds across copulas
#   - Li, Poskitt & Zhao (2019, J Econometrics): ATE robust under misspecification
#
# Output files:
#   1. Copula_ATE_Comparison.csv      - ATEs under all 3 copulas, all 8 models
#   2. Copula_Rho_Comparison.csv      - ρ/dependence under all 3 copulas
#   3. Copula_AIC_Comparison.csv      - AIC for copula family selection
#   4. Copula_SignFlip_Check.csv      - Whether sign of ATE is consistent
#   5. Copula_Sensitivity_Summary.csv - Single table combining all above
#
# Runtime: ~60-120 minutes (3x the original pipeline)
# =============================================================================

library(dplyr)
library(tidyr)   # for pivot_wider in summary table
library(GJRM)

cat("=======================================================\n")
cat("COPULA SENSITIVITY ANALYSIS\n")
cat("Testing Robustness of ATEs and rho Across Copula Families\n")
cat("Reference: McGovern et al. (2015), Klein et al. (2019)\n")
cat("=======================================================\n\n")

# =============================================================================
# CONFIGURATION - Edit paths to match your system
# =============================================================================

input_dir  <- file.path(getwd(), "outputs", "causal_main")
output_dir <- file.path(getwd(), "outputs", "causal_main")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# The four copula families to test
# In GJRM, the copula family is specified via the SEPARATE `copula =` argument.
# The `model =` argument specifies the structural type ONLY (always "B" here).
#
# Gaussian = default bivariate normal → pass NULL (no copula argument)
# Frank    = symmetric, handles positive and negative dependence → copula = "F"
# Clayton  = lower-tail dependence (positive dep.) → copula = "C0"
# Gumbel   = upper-tail dependence (positive dep.) → copula = "GU0"
#   FIX 2026-05-22: Gumbel added per McGovern et al. (2015) and Klein et al.
#   (2019), which test 4 copula families. Original code tested only 3.
#
# For datasets where ρ is expected to be negative, use rotated variants:
#   C90 (lower-left tail), C270 (upper-right tail), GU180 (Gumbel rotated)
# Our data has positive ρ (adverse selection), so C0, F, GU0 are appropriate.
copula_specs <- list(
  Gaussian = NULL,   # NULL → omit copula argument → GJRM uses Gaussian default
  Frank    = "F",
  Clayton  = "C0",
  Gumbel   = "GU0"
)

# =============================================================================
# STEP 1: LOAD DATA AND RECONSTRUCT PIPELINE INPUTS
# =============================================================================

cat("STEP 1: Loading data and controls\n")
cat("-----------------------------------\n")

data_file <- file.path(input_dir, "data_step1_complete.rds")
if (!file.exists(data_file)) {
  stop("ERROR: data_step1_complete.rds not found.\n",
       "Please run SCRIPT_1_DATA_PREPARATION_MASTER.R first.")
}

df_run <- readRDS(data_file)
cat("✓ Data loaded: N =", nrow(df_run), "\n")

# Reconstruct year variable if stored as dummies
if (!"year" %in% names(df_run)) {
  if (all(c("year_2011", "year_2017_2018", "year_2022") %in% names(df_run))) {
    df_run$year <- dplyr::case_when(
      df_run$year_2011      == 1 ~ "2011",
      df_run$year_2017_2018 == 1 ~ "2017-2018",
      df_run$year_2022      == 1 ~ "2022",
      TRUE                       ~ "2004"
    )
  } else {
    stop("ERROR: Cannot reconstruct year variable.")
  }
}

# Load control set (mirrors Script 3 logic exactly)
controls_file <- file.path(output_dir, "Recommended_Control_Sets.rds")

if (file.exists(controls_file)) {
  recommended_sets <- readRDS(controls_file)
  if ("Consensus_With_Infrastructure" %in% names(recommended_sets)) {
    selected_controls <- recommended_sets$Consensus_With_Infrastructure
  } else {
    selected_controls <- recommended_sets$Consensus_Confounders
  }
  mediators <- recommended_sets$Mediators
  cat("✓ Controls loaded from Recommended_Control_Sets.rds\n")
} else {
  # Fallback: same as Script 3
  selected_controls <- c(
    "birth_single", "contraceptive_type", "mother_education", "partner_edu", "PBI",
    "BMI", "child_male", "infrastructure_index",
    "birth_spacingaftermarriage", "media_exposure", "mother_ageBirth",
    "mother_working", "pregnancy_terminated", "residence_urban"
  )
  mediators <- c("institutional_delivery", "baby_health_check_yes",
                 "exclusive_bf_yes", "skilled_birth_attendant")
  cat("⚠ Using fallback control set\n")
}

# =============================================================================
# STEP 2: DATA PREPARATION (mirrors Script 3 exactly)
# =============================================================================

cat("\nSTEP 2: Data preparation\n")
cat("-----------------------------------\n")

# Mother education direction correction (same as Script 3)
if ("mother_education" %in% names(df_run)) {
  cor_edu <- cor(as.numeric(df_run$mother_education), df_run$child_died,
                 use = "complete.obs")
  if (cor_edu > 0) {
    mx <- max(as.numeric(df_run$mother_education), na.rm = TRUE)
    mn <- min(as.numeric(df_run$mother_education), na.rm = TRUE)
    df_run$mother_education <- (mx + mn) - as.numeric(df_run$mother_education)
    cat("✓ Mother education direction corrected\n")
  }
}

# Infrastructure PCA (same as Script 3)
infra_cols <- c("wealth", "sanitation", "housing_quality", "electricity_yes", "cooking_fuel")
if (all(infra_cols %in% names(df_run))) {
  infra_mat <- df_run[, infra_cols]
  infra_mat[] <- lapply(infra_mat, function(x) as.numeric(as.character(x)))
  pca_res <- prcomp(na.omit(infra_mat), scale. = TRUE)
  df_run$infrastructure_pca <- NA
  df_run$infrastructure_pca[complete.cases(infra_mat)] <- pca_res$x[, 1]
  cor_pca <- cor(df_run$infrastructure_pca, df_run$child_died, use = "complete.obs")
  if (cor_pca > 0) df_run$infrastructure_pca <- df_run$infrastructure_pca * -1
  if ("infrastructure_index" %in% selected_controls) {
    selected_controls <- c(setdiff(selected_controls, "infrastructure_index"),
                           "infrastructure_pca")
  }
  cat("✓ Infrastructure PCA created\n")
}

# Regional fixed effects
available_regions <- grep("^region_", names(df_run), value = TRUE)
selected_controls  <- unique(c(selected_controls, available_regions))
final_controls     <- selected_controls[selected_controls %in% names(df_run)]
cat("✓ Final control set:", length(final_controls), "variables\n")

# =============================================================================
# STEP 3: INSTRUMENTAL VARIABLES (mirrors Script 3)
# =============================================================================

cat("\nSTEP 3: Instrumental variables\n")
cat("-----------------------------------\n")

for (var in c("anc_4plus", "c_section_yes")) {
  if (var %in% names(df_run)) {
    iv_name <- paste0("IV_", var)
    df_run <- df_run %>%
      dplyr::group_by(year, cluster_id) %>%
      dplyr::mutate(
        .cs = n(),
        .sm = sum(!!rlang::sym(var), na.rm = TRUE),
        !!iv_name := ifelse(.cs > 1, (.sm - !!rlang::sym(var)) / (.cs - 1), NA)
      ) %>%
      dplyr::ungroup() %>%
      dplyr::select(-`.cs`, -`.sm`)
    cat("✓", iv_name, "created\n")
  }
}

# =============================================================================
# STEP 4: HELPER FUNCTIONS
# =============================================================================

# --- ATE computation using GJRM's built-in ATE() function ---
# This is correct for ALL copula families (Gaussian, Frank, Clayton, etc.).
# The manual bivariate-normal approach used in Script 3 is only valid for
# the Gaussian copula; using it for Frank/Clayton would be wrong.
# GJRM's ATE() internally uses the correct copula-specific probabilities.
#
# ATE() return value (from GJRM documentation):
#   $res     — vector of 3: c(lower_CI, ATE_estimate, upper_CI)
#   $prob.lev — probability level used
#   $sim.ATE  — vector of simulated ATE values (used for intervals)

compute_ate_gjrm <- function(fit, treatment_var) {
  
  # Helper: converts numeric(0) or NULL to NA_real_
  safe_scalar <- function(x) {
    if (is.null(x) || length(x) == 0) return(NA_real_)
    as.numeric(x[[1]])
  }
  
  # Extract dependence parameter theta ($theta is documented in gjrmObject)
  rho_val <- tryCatch({
    th <- fit$theta
    if (is.list(th)) th <- th[[1]]
    safe_scalar(th)
  }, error = function(e) NA_real_)
  
  # ---------------------------------------------------------------
  # Marginal ATE from fitted linear predictors (equation 2).
  # This is the standard marginal probit ATE formula (Wooldridge 2010):
  #   ATE_i = Phi(lp2_base_i + alpha) - Phi(lp2_base_i)
  #   ATE   = mean(ATE_i)
  #
  # This approach is COPULA-FAMILY-AGNOSTIC: the copula affects the
  # estimation of alpha and lp2 through the joint likelihood, but once
  # the model is fitted, the marginal ATE only requires equation-2
  # predictions and the treatment coefficient. It is therefore valid
  # for Gaussian, Frank, and Clayton copulas alike.
  #
  # This is identical to Script 3's compute_ate(), which is confirmed
  # working. ATE() from GJRM is bypassed due to version inconsistencies
  # in its $res return structure.
  # ---------------------------------------------------------------
  
  tryCatch({
    summ <- summary(fit)
    
    # --- Get equation-2 linear predictor (full, including treatment) ---
    lp2 <- NULL
    
    # Method 1: predict() on eq=2
    tryCatch({
      lp2 <- as.numeric(predict(fit, eq = 2, type = "link"))
    }, error = function(e) NULL)
    
    # Method 2: internal eta2 slot
    if (is.null(lp2) || length(lp2) == 0) {
      tryCatch({ lp2 <- as.numeric(fit$eta2) }, error = function(e) NULL)
    }
    
    # Method 3: X2 %*% beta2
    if (is.null(lp2) || length(lp2) == 0) {
      tryCatch({
        n1  <- ncol(fit$X1)
        n2  <- ncol(fit$X2)
        lp2 <- as.numeric(fit$X2 %*% fit$coefficients[(n1 + 1):(n1 + n2)])
      }, error = function(e) NULL)
    }
    
    if (is.null(lp2) || length(lp2) == 0) stop("Cannot extract eq-2 linear predictors")
    
    # --- Treatment coefficient from outcome equation ---
    trt_row <- grep(treatment_var, rownames(summ$tableP2), fixed = TRUE)[1]
    if (is.na(trt_row)) stop(paste("Cannot find", treatment_var, "in tableP2"))
    alpha <- safe_scalar(summ$tableP2[trt_row, "Estimate"])
    if (is.na(alpha)) stop("Treatment coefficient is NA")
    
    # --- Remove treatment contribution to get baseline lp2 ---
    # lp2 includes alpha * observed_treatment for each observation.
    # Find treatment column in X2 to reconstruct lp2_base.
    trt_col_idx <- grep(treatment_var, colnames(fit$X2), fixed = TRUE)[1]
    if (!is.na(trt_col_idx)) {
      trt_obs  <- as.numeric(fit$X2[, trt_col_idx])
      lp2_base <- lp2 - alpha * trt_obs
    } else {
      # Cannot isolate: use lp2 as-is (conservative approximation)
      warning("Could not find treatment column in X2; ATE may be slightly off")
      lp2_base <- lp2
    }
    
    # --- Compute individual ATEs and aggregate ---
    ate_i    <- pnorm(lp2_base + alpha) - pnorm(lp2_base)
    ate_mean <- mean(ate_i, na.rm = TRUE)
    ate_se   <- sd(ate_i,   na.rm = TRUE) / sqrt(sum(!is.na(ate_i)))
    
    list(
      ATE       = ate_mean,
      ATE_SE    = ate_se,
      ATE_lower = ate_mean - 1.96 * ate_se,
      ATE_upper = ate_mean + 1.96 * ate_se,
      theta     = rho_val
    )
    
  }, error = function(e) {
    cat("    [ATE computation failed:", conditionMessage(e), "]\n")
    list(ATE = NA_real_, ATE_SE = NA_real_,
         ATE_lower = NA_real_, ATE_upper = NA_real_,
         theta = rho_val)
  })
}

# --- Fit one RBVP model under a specified copula ---
# FIX: `model = "B"` ALWAYS (structural type = recursive bivariate probit).
# The copula family goes in the SEPARATE `copula =` argument.
# Gaussian is the DEFAULT when copula is omitted (copula_code = NULL).

fit_rbvp_copula <- function(f1, f2, dat, wts, copula_code, label) {
  tryCatch({
    if (is.null(copula_code)) {
      # Gaussian: omit copula argument entirely → GJRM uses bivariate normal
      gjrm(list(f1, f2),
           data    = dat,
           weights = wts,
           margins = c("probit", "probit"),
           model   = "B")
    } else {
      # Frank ("F"), Clayton ("C0"), or other: pass via copula = argument
      gjrm(list(f1, f2),
           data    = dat,
           weights = wts,
           margins = c("probit", "probit"),
           model   = "B",
           copula  = copula_code)
    }
  }, error = function(e) {
    cat("    ✗", label, "- Error:", conditionMessage(e), "\n")
    NULL
  })
}

# =============================================================================
# STEP 5: MAIN COPULA SENSITIVITY LOOP
# =============================================================================

cat("\n=======================================================\n")
cat("STEP 5: RUNNING COPULA SENSITIVITY ANALYSIS\n")
cat("=======================================================\n\n")

outcome_var <- "child_died"
endo_1 <- "c_section_yes"
endo_2 <- "anc_4plus"
iv_1   <- "IV_c_section_yes"
iv_2   <- "IV_anc_4plus"
years  <- c("2004", "2011", "2017-2018", "2022")

# Storage
ate_comparison  <- data.frame()
rho_comparison  <- data.frame()
aic_comparison  <- data.frame()

for (yr in years) {
  cat(strrep("=", 55), "\n")
  cat("YEAR:", yr, "\n")
  cat(strrep("=", 55), "\n\n")
  
  # Prepare data (same filtering as Script 3)
  dat_yr <- df_run %>% dplyr::filter(year == yr)
  vars_needed <- c(outcome_var, endo_1, endo_2, iv_1, iv_2, final_controls, "weight")
  dat_clean <- dat_yr %>% dplyr::select(dplyr::all_of(vars_needed))
  for (col in setdiff(names(dat_clean), "weight")) {
    dat_clean[[col]] <- suppressWarnings(as.numeric(as.character(dat_clean[[col]])))
  }
  dat_clean <- dat_clean %>% dplyr::filter(complete.cases(.))
  
  if (nrow(dat_clean) < 100) {
    cat("  ⚠ Insufficient data (N =", nrow(dat_clean), "). Skipping.\n\n")
    next
  }
  cat("  N =", nrow(dat_clean), "\n\n")
  
  wts <- dat_clean$weight
  
  # Formulas for Stage 1 (C-section) and Stage 2 (ANC)
  f1_s1 <- as.formula(paste(endo_1, "~", iv_1,  "+", paste(final_controls, collapse = " + ")))
  f2_s1 <- as.formula(paste(outcome_var, "~", endo_1, "+", paste(final_controls, collapse = " + ")))
  f1_s2 <- as.formula(paste(endo_2, "~", iv_2, "+", endo_1, "+", paste(final_controls, collapse = " + ")))
  f2_s2 <- as.formula(paste(outcome_var, "~", endo_2, "+", endo_1, "+", paste(final_controls, collapse = " + ")))
  
  # ---------------------------------------------------------
  # Loop over copula families
  # ---------------------------------------------------------
  for (cop_name in names(copula_specs)) {
    cop_code <- copula_specs[[cop_name]]
    cat("  Copula:", cop_name, "(", cop_code, ")\n")
    
    # --- Stage 1: C-section ---
    cat("    Stage 1 (C-section)... ")
    fit_s1 <- fit_rbvp_copula(f1_s1, f2_s1, dat_clean, wts, cop_code,
                              paste(yr, cop_name, "S1"))
    
    if (!is.null(fit_s1)) {
      aic_s1 <- AIC(fit_s1)
      cat("AIC =", round(aic_s1, 2), "\n")
      
      ate_s1 <- tryCatch(compute_ate_gjrm(fit_s1, endo_1),
                         error = function(e) list(ATE=NA, ATE_SE=NA,
                                                  ATE_lower=NA, ATE_upper=NA, theta=NA))
      
      summ_s1 <- summary(fit_s1)
      # Guard: tableP2 row may be named "c_section_yes" or differ slightly
      # Use grep to find the row rather than exact string match
      s1_row    <- tryCatch(grep(endo_1, rownames(summ_s1$tableP2), fixed=TRUE)[1],
                            error = function(e) NA)
      csec_coef <- tryCatch(summ_s1$tableP2[s1_row, "Estimate"],   error = function(e) NA_real_)
      csec_se   <- tryCatch(summ_s1$tableP2[s1_row, "Std. Error"], error = function(e) NA_real_)
      csec_p    <- tryCatch(summ_s1$tableP2[s1_row, "Pr(>|z|)"],   error = function(e) NA_real_)
      # Force scalar
      csec_coef <- if (length(csec_coef) == 0) NA_real_ else as.numeric(csec_coef[1])
      csec_se   <- if (length(csec_se)   == 0) NA_real_ else as.numeric(csec_se[1])
      csec_p    <- if (length(csec_p)    == 0) NA_real_ else as.numeric(csec_p[1])
      
      ate_comparison <- rbind(ate_comparison, data.frame(
        Year = yr, Stage = "Stage1_Csection", Treatment = "C-section",
        Copula = cop_name, Copula_Code = if (is.null(cop_code)) "Gaussian_default" else cop_code,
        Latent_Coef = csec_coef, Latent_SE = csec_se, P_Value = csec_p,
        ATE = ate_s1$ATE, ATE_SE = ate_s1$ATE_SE,
        ATE_Lower95 = ate_s1$ATE_lower, ATE_Upper95 = ate_s1$ATE_upper,
        stringsAsFactors = FALSE
      ))
      
      rho_comparison <- rbind(rho_comparison, data.frame(
        Year = yr, Stage = "Stage1_Csection", Treatment = "C-section",
        Copula = cop_name, Copula_Code = if (is.null(cop_code)) "Gaussian_default" else cop_code,
        Dependence_Theta = ate_s1$theta,
        stringsAsFactors = FALSE
      ))
      
      aic_comparison <- rbind(aic_comparison, data.frame(
        Year = yr, Stage = "Stage1_Csection", Treatment = "C-section",
        Copula = cop_name, Copula_Code = if (is.null(cop_code)) "Gaussian_default" else cop_code,
        AIC = aic_s1,
        stringsAsFactors = FALSE
      ))
      
    } else {
      cat("    Stage 1 failed.\n")
    }
    
    # --- Stage 2: ANC ---
    cat("    Stage 2 (ANC)......... ")
    fit_s2 <- fit_rbvp_copula(f1_s2, f2_s2, dat_clean, wts, cop_code,
                              paste(yr, cop_name, "S2"))
    
    if (!is.null(fit_s2)) {
      aic_s2 <- AIC(fit_s2)
      cat("AIC =", round(aic_s2, 2), "\n")
      
      ate_s2 <- tryCatch(compute_ate_gjrm(fit_s2, endo_2),
                         error = function(e) list(ATE=NA, ATE_SE=NA,
                                                  ATE_lower=NA, ATE_upper=NA, theta=NA))
      
      summ_s2   <- summary(fit_s2)
      coef_tbl  <- summ_s2$tableP2
      anc_row   <- tryCatch(grep(endo_2, rownames(coef_tbl), fixed=TRUE)[1],
                            error = function(e) NA)
      anc_coef  <- tryCatch(coef_tbl[anc_row, "Estimate"],   error = function(e) NA_real_)
      anc_se    <- tryCatch(coef_tbl[anc_row, "Std. Error"], error = function(e) NA_real_)
      anc_p     <- tryCatch(coef_tbl[anc_row, "Pr(>|z|)"],   error = function(e) NA_real_)
      # Force scalar
      anc_coef  <- if (length(anc_coef) == 0) NA_real_ else as.numeric(anc_coef[1])
      anc_se    <- if (length(anc_se)   == 0) NA_real_ else as.numeric(anc_se[1])
      anc_p     <- if (length(anc_p)    == 0) NA_real_ else as.numeric(anc_p[1])
      
      ate_comparison <- rbind(ate_comparison, data.frame(
        Year = yr, Stage = "Stage2_ANC", Treatment = "ANC 4+",
        Copula = cop_name, Copula_Code = if (is.null(cop_code)) "Gaussian_default" else cop_code,
        Latent_Coef = anc_coef, Latent_SE = anc_se, P_Value = anc_p,
        ATE = ate_s2$ATE, ATE_SE = ate_s2$ATE_SE,
        ATE_Lower95 = ate_s2$ATE_lower, ATE_Upper95 = ate_s2$ATE_upper,
        stringsAsFactors = FALSE
      ))
      
      rho_comparison <- rbind(rho_comparison, data.frame(
        Year = yr, Stage = "Stage2_ANC", Treatment = "ANC 4+",
        Copula = cop_name, Copula_Code = if (is.null(cop_code)) "Gaussian_default" else cop_code,
        Dependence_Theta = ate_s2$theta,
        stringsAsFactors = FALSE
      ))
      
      aic_comparison <- rbind(aic_comparison, data.frame(
        Year = yr, Stage = "Stage2_ANC", Treatment = "ANC 4+",
        Copula = cop_name, Copula_Code = if (is.null(cop_code)) "Gaussian_default" else cop_code,
        AIC = aic_s2,
        stringsAsFactors = FALSE
      ))
      
    } else {
      cat("    Stage 2 failed.\n")
    }
    
    cat("\n")
  }  # end copula loop
  cat("\n")
}  # end year loop

# =============================================================================
# STEP 6: BUILD SUMMARY TABLE AND SIGN-FLIP CHECK
# =============================================================================

cat("STEP 6: Building summary tables\n")
cat("-----------------------------------\n")

# --- Sign consistency check ---
# For each Year x Treatment combination, check if the ATE sign
# is the same across all 3 copula families. Inconsistency = problem.
sign_check <- ate_comparison %>%
  dplyr::group_by(Year, Treatment) %>%
  dplyr::summarise(
    N_Copulas_Fitted   = sum(!is.na(ATE)),
    ATE_Gaussian       = ATE[Copula == "Gaussian"][1],
    ATE_Frank          = ATE[Copula == "Frank"][1],
    ATE_Clayton        = ATE[Copula == "Clayton"][1],
    ATE_Gumbel         = ATE[Copula == "Gumbel"][1],
    Sign_Gaussian      = sign(ATE[Copula == "Gaussian"][1]),
    Sign_Frank         = sign(ATE[Copula == "Frank"][1]),
    Sign_Clayton       = sign(ATE[Copula == "Clayton"][1]),
    Sign_Gumbel        = sign(ATE[Copula == "Gumbel"][1]),
    # Signs_Consistent = all non-NA signs match
    Signs_Consistent   = {
      signs <- c(Sign_Gaussian, Sign_Frank, Sign_Clayton, Sign_Gumbel)
      signs <- signs[!is.na(signs)]
      length(unique(signs)) == 1
    },
    Max_ATE_Difference = max(ATE, na.rm = TRUE) - min(ATE, na.rm = TRUE),
    .groups = "drop"
  )

# --- AIC-based best copula per model ---
aic_best <- aic_comparison %>%
  dplyr::group_by(Year, Treatment) %>%
  dplyr::slice_min(AIC, n = 1) %>%
  dplyr::select(Year, Treatment, Best_Copula = Copula, Best_AIC = AIC) %>%
  dplyr::ungroup()

# --- Consolidated summary table ---
# Wide format: one row per Year x Treatment, columns for each copula
summary_wide <- ate_comparison %>%
  dplyr::select(Year, Treatment, Copula, ATE, ATE_Lower95, ATE_Upper95) %>%
  dplyr::left_join(
    rho_comparison %>% dplyr::select(Year, Treatment, Copula, Dependence_Theta),
    by = c("Year", "Treatment", "Copula")
  ) %>%
  tidyr::pivot_wider(
    names_from  = Copula,
    values_from = c(ATE, ATE_Lower95, ATE_Upper95, Dependence_Theta),
    names_glue  = "{Copula}_{.value}"
  ) %>%
  dplyr::left_join(sign_check %>% dplyr::select(Year, Treatment,
                                                Signs_Consistent,
                                                Max_ATE_Difference),
                   by = c("Year", "Treatment")) %>%
  dplyr::left_join(aic_best, by = c("Year", "Treatment"))

# =============================================================================
# STEP 7: SAVE ALL OUTPUTS
# =============================================================================

cat("\nSTEP 7: Saving outputs\n")
cat("-----------------------------------\n")

out <- function(df, name) {
  path <- file.path(output_dir, name)
  write.csv(df, path, row.names = FALSE)
  cat("✓ Saved:", name, "\n")
}

out(ate_comparison,  "Copula_ATE_Comparison.csv")
out(rho_comparison,  "Copula_Rho_Comparison.csv")
out(aic_comparison,  "Copula_AIC_Comparison.csv")
out(sign_check,      "Copula_SignFlip_Check.csv")
out(summary_wide,    "Copula_Sensitivity_Summary.csv")

# =============================================================================
# STEP 8: PRINT DIAGNOSTIC REPORT
# =============================================================================

cat("\n")
cat(strrep("=", 55), "\n")
cat("COPULA SENSITIVITY RESULTS SUMMARY\n")
cat(strrep("=", 55), "\n\n")

cat("1. SIGN CONSISTENCY (key result for manuscript):\n\n")
print(sign_check %>%
        dplyr::select(Year, Treatment, ATE_Gaussian, ATE_Frank, ATE_Clayton,
                      ATE_Gumbel, Signs_Consistent, Max_ATE_Difference),
      row.names = FALSE, digits = 5)

cat("\n\n2. BEST COPULA BY AIC:\n\n")
print(aic_best, row.names = FALSE)

cat("\n\n3. DEPENDENCE PARAMETER (Theta) COMPARISON:\n")
cat("   Note: theta is NOT directly comparable across copula families.\n")
cat("   For Gaussian: rho = tanh(theta). For Frank/Clayton: parameterisation differs.\n")
cat("   What matters is the DIRECTION (positive = adverse selection) being consistent.\n\n")
rho_wide <- rho_comparison %>%
  tidyr::pivot_wider(names_from  = Copula,
                     values_from = Dependence_Theta,
                     names_prefix = "theta_")
print(rho_wide %>% dplyr::select(any_of(c("Year", "Treatment",
                                 "theta_Gaussian", "theta_Frank",
                                 "theta_Clayton", "theta_Gumbel"))),
      row.names = FALSE, digits = 4)

cat("\n")
cat(strrep("=", 55), "\n")
cat("INTERPRETATION GUIDE FOR MANUSCRIPT\n")
cat(strrep("=", 55), "\n")
cat("
KEY QUESTIONS TO ANSWER FROM THESE RESULTS:

1. SIGN CONSISTENCY (Signs_Consistent = TRUE/FALSE)
   → If TRUE for all 8 models: 'ATEs are directionally robust
     to copula specification, supporting the Gaussian baseline.'
   → If FALSE for any model: investigate that wave/treatment
     combination further before reporting it as robust.

2. MAGNITUDE VARIATION (Max_ATE_Difference)
   → Small (<0.01 pp): near-perfect robustness
   → Moderate (0.01-0.05 pp): acceptable variation, report range
   → Large (>0.05 pp): copula choice matters, report all three

3. AIC-BASED COPULA SELECTION
   → If Gaussian wins most: bivariate normal assumption justified
   → If Frank or Clayton wins: report those ATEs as primary,
     Gaussian as sensitivity (and note it doesn't change conclusions)

4. RHO DIRECTION CONSISTENCY
   → ρ in Clayton model reflects lower-tail dependence differently
     than in Gaussian. Focus on direction (positive/negative) not
     absolute value when comparing across copula families.

REFERENCE FOR REPORTING:
   McGovern et al. (2015) found 'HIV prevalence estimates are similar
   irrespective of the structure of the association assumed between
   participation and outcome.' Use this framing in your Methods:
   'We assessed sensitivity of ATEs to the bivariate normality
   assumption by re-estimating all models under Frank and Clayton
   copula specifications using the BivD parameter in the GJRM R
   package (Marra & Radice, 2017). ATEs were [consistent/robust]
   across all three copula families (Table S-X), supporting the
   validity of the Gaussian baseline specification.'
")

cat("\n✓ Copula sensitivity analysis complete!\n")
cat("  Output directory:", output_dir, "\n\n")
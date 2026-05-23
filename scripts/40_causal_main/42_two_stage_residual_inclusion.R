# =============================================================================
# SCRIPT: TWO-STAGE RESIDUAL INCLUSION (2SRI) ROBUSTNESS CHECK
# =============================================================================
# Purpose:  Triangulate primary RBVP results using 2SRI (Terza et al. 2008).
#           2SRI is consistent for nonlinear models with endogenous binary
#           regressors WITHOUT requiring distributional assumptions on the
#           joint error structure. Sign-consistency with RBVP closes the
#           key reviewer objection about parametric assumptions.
#
# Method:   Per Terza (2018) protocol for binary treatment, binary outcome:
#   Stage 1: Probit(treatment | IV, X) → residuals v̂_i = y_i - Φ(x'β̂₁)
#   Stage 2: Probit(outcome | treatment, X, v̂) → treatment coefficient is
#            the 2SRI endogeneity-corrected structural estimate.
#   ATE:     Computed at v̂ = 0 (purging endogeneity component), averaged
#            across all observations. Standard errors via bootstrap.
#
# Design:
#   - Mirrors Script 3 data loading / control selection exactly
#   - Parallel sequential structure: Stage 1 = C-section, Stage 2 = ANC
#   - Stage 2 conditions on C-section (same as RBVP Stage 2)
#   - Loads RBVP ATEs from existing CSVs for direct comparison
#
# References:
#   Terza JV, Basu A, Rathouz PJ (2008). Two-stage residual inclusion
#     estimation. J Health Economics.
#   Terza JV (2018). Two-stage residual inclusion in health services
#     research. Health Services Research.
#   Wooldridge JM (2015). Control function methods in applied econometrics.
#     J Human Resources.
#
# Input:  data_step1_complete.rds, Recommended_Control_Sets.rds,
#         Formal_ATE_Results.csv (RBVP baseline for comparison)
# Output: 5 CSV files
# Runtime: ~10-20 minutes (no GJRM, just probit)
# =============================================================================

library(dplyr)

cat("=============================================\n")
cat("2SRI ROBUSTNESS CHECK\n")
cat("Two-Stage Residual Inclusion (Terza 2018)\n")
cat("=============================================\n\n")

# Directories — match Script 3 exactly
input_dir  <- file.path(getwd(), "outputs", "causal_main")
output_dir <- file.path(getwd(), "outputs", "causal_main")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Number of bootstrap replications for SE estimation
# 500 is standard per Terza (2018); increase to 1000 for final submission.
# Allow override via env var N_BOOT for smoke-testing (fix 2026-05-22).
N_BOOT <- as.integer(Sys.getenv("N_BOOT", "500"))
if (is.na(N_BOOT) || N_BOOT < 1) N_BOOT <- 500

# =============================================================================
# STEP 1: LOAD DATA & CONTROLS (identical to Script 3)
# =============================================================================

cat("STEP 1: Loading data and controls\n")
cat("-----------------------------------\n")

data_file <- file.path(input_dir, "data_step1_complete.rds")
if (!file.exists(data_file)) {
  stop("data_step1_complete.rds not found. Run Script 1 first.")
}
df_run <- readRDS(data_file)
cat("✓ Data loaded: N =", nrow(df_run), "\n")

controls_file <- file.path(output_dir, "Recommended_Control_Sets.rds")
if (file.exists(controls_file)) {
  recommended_sets <- readRDS(controls_file)
  if ("Consensus_With_Infrastructure" %in% names(recommended_sets)) {
    selected_controls <- recommended_sets$Consensus_With_Infrastructure
    cat("✓ Controls: Consensus + Infrastructure override\n")
  } else {
    selected_controls <- recommended_sets$Consensus_Confounders
    cat("✓ Controls: Pure consensus\n")
  }
  mediators <- recommended_sets$Mediators
} else {
  # Fallback identical to Script 3
  selected_controls <- c(
    "birth_single", "contraceptive_type", "mother_education", "partner_edu",
    "PBI", "BMI", "child_male", "infrastructure_index",
    "birth_spacingaftermarriage", "media_exposure", "mother_ageBirth",
    "mother_working", "pregnancy_terminated", "residence_urban"
  )
  mediators <- c("institutional_delivery", "baby_health_check_yes",
                 "exclusive_bf_yes", "skilled_birth_attendant")
  cat("⚠ Using fallback control set\n")
}

# Reconstruct year variable if needed
if (!"year" %in% names(df_run)) {
  df_run$year <- dplyr::case_when(
    df_run$year_2011      == 1 ~ "2011",
    df_run$year_2017_2018 == 1 ~ "2017-2018",
    df_run$year_2022      == 1 ~ "2022",
    TRUE ~ "2004"
  )
}

# =============================================================================
# STEP 2: DATA PREPARATION (identical to Script 3)
# =============================================================================

cat("\nSTEP 2: Data preparation\n")
cat("-----------------------------------\n")

# Mother education direction correction
if ("mother_education" %in% names(df_run)) {
  cor_edu <- cor(as.numeric(df_run$mother_education), df_run$child_died,
                 use = "complete.obs")
  if (cor_edu > 0) {
    mx <- max(as.numeric(df_run$mother_education), na.rm = TRUE)
    mn <- min(as.numeric(df_run$mother_education), na.rm = TRUE)
    df_run$mother_education <- (mx + mn) - as.numeric(df_run$mother_education)
    cat("✓ Mother education flipped (higher = more educated)\n")
  }
}

# Infrastructure PCA
infra_cols <- c("wealth", "sanitation", "housing_quality",
                "electricity_yes", "cooking_fuel")
if (all(infra_cols %in% names(df_run))) {
  infra_mat <- df_run[, infra_cols]
  infra_mat[] <- lapply(infra_mat, function(x) as.numeric(as.character(x)))
  pca_res <- prcomp(na.omit(infra_mat), scale. = TRUE)
  df_run$infrastructure_pca <- NA
  df_run$infrastructure_pca[complete.cases(infra_mat)] <- pca_res$x[, 1]
  cor_pca <- cor(df_run$infrastructure_pca, df_run$child_died, use = "complete.obs")
  if (cor_pca > 0) df_run$infrastructure_pca <- -df_run$infrastructure_pca
  if ("infrastructure_index" %in% selected_controls) {
    selected_controls <- c(setdiff(selected_controls, "infrastructure_index"),
                           "infrastructure_pca")
  }
  cat("✓ Infrastructure PCA created\n")
}

# =============================================================================
# STEP 3: IV CREATION (identical to Script 3)
# =============================================================================

cat("\nSTEP 3: Instrument creation\n")
cat("-----------------------------------\n")

for (var in c("c_section_yes", "anc_4plus")) {
  iv_name <- paste0("IV_", var)
  df_run <- df_run %>%
    group_by(year, cluster_id) %>%
    mutate(
      cluster_size = n(),
      cluster_sum  = sum(!!sym(var), na.rm = TRUE),
      !!iv_name := ifelse(cluster_size > 1,
                          (cluster_sum - !!sym(var)) / (cluster_size - 1),
                          NA)
    ) %>%
    ungroup() %>%
    select(-cluster_size, -cluster_sum)
  cat("✓", iv_name, "created\n")
}

# =============================================================================
# STEP 4: CONTROL FINALISATION (identical to Script 3)
# =============================================================================

cat("\nSTEP 4: Finalising control set\n")
cat("-----------------------------------\n")

available_regions <- grep("^region_", names(df_run), value = TRUE)
selected_controls <- unique(c(selected_controls, available_regions))
final_controls    <- selected_controls[selected_controls %in% names(df_run)]

cat("✓ Final controls: n =", length(final_controls), "\n")
cat("✓ Regional fixed effects: n =", length(available_regions), "\n\n")

# Variable name aliases (consistent with Script 3)
outcome_var <- "child_died"
endo_1      <- "c_section_yes"
endo_2      <- "anc_4plus"
iv_1        <- "IV_c_section_yes"
iv_2        <- "IV_anc_4plus"
years       <- c("2004", "2011", "2017-2018", "2022")

# =============================================================================
# STEP 5: HELPER FUNCTIONS
# =============================================================================

# --- 5a. Compute generalised residuals from a fitted probit model ---
# Per Terza (2008): raw residual v̂_i = y_i - Φ(x'β̂)
# This is the standard "generalised residual" for the probit control function.
get_probit_residuals <- function(fit_probit) {
  y       <- fit_probit$y
  p_hat   <- fitted(fit_probit)             # Φ(x'β̂), on probability scale
  resid_v <- y - p_hat                      # Raw residual
  return(resid_v)
}

# --- 5b. Compute 2SRI ATE at v̂ = 0 ---
# Per Terza (2018) Section 3: the structural ATE is evaluated by setting
# the residual to its expected value (0), removing the endogeneity component.
# ATE_i = Φ(lp_base_i + γ̂_v * 0 + α̂) - Φ(lp_base_i + γ̂_v * 0)
#       = Φ(lp_base_i + α̂) - Φ(lp_base_i)
# where lp_base_i is the linear predictor excluding both treatment and residual.
#
# Arguments:
#   fit_s2       : fitted stage-2 probit (with residual included)
#   treatment_var: name of the treatment variable (e.g. "c_section_yes")
#   resid_var    : name of the residual variable in the data
#   data         : data frame used to fit stage-2
compute_2sri_ate <- function(fit_s2, treatment_var, resid_var, data) {
  
  beta    <- coef(fit_s2)
  X_mat   <- model.matrix(fit_s2)              # design matrix
  
  # Identify column positions
  trt_col   <- which(colnames(X_mat) == treatment_var)
  resid_col <- which(colnames(X_mat) == resid_var)
  
  if (length(trt_col) == 0)
    stop(paste("Treatment variable", treatment_var, "not found in model matrix"))
  if (length(resid_col) == 0)
    stop(paste("Residual variable", resid_var, "not found in model matrix"))
  
  alpha   <- beta[trt_col]    # structural treatment coefficient
  gamma_v <- beta[resid_col]  # residual coefficient (endogeneity correction)
  
  # lp_base: linear predictor with treatment=0 and residual=0
  X_base       <- X_mat
  X_base[, trt_col]   <- 0
  X_base[, resid_col] <- 0
  lp_base <- as.numeric(X_base %*% beta)
  
  # ATE_i = Φ(lp_base_i + α) - Φ(lp_base_i)
  ate_i    <- pnorm(lp_base + alpha) - pnorm(lp_base)
  ate_mean <- mean(ate_i, na.rm = TRUE)
  ate_se   <- sd(ate_i,   na.rm = TRUE) / sqrt(sum(!is.na(ate_i)))
  
  list(
    ATE       = ate_mean,
    ATE_SE    = ate_se,
    ATE_lower = ate_mean - 1.96 * ate_se,
    ATE_upper = ate_mean + 1.96 * ate_se,
    alpha     = alpha,   # structural coefficient (latent scale)
    gamma_v   = gamma_v  # residual coefficient (test of endogeneity)
  )
}

# --- 5c. Bootstrap standard errors for 2SRI ---
# Bootstraps the ENTIRE two-stage procedure to obtain correct SEs.
# Ignoring the two-step nature would understate uncertainty.
# Only applied to the ATE (not the latent coefficient, which is less
# interpretable as a marginal quantity).
bootstrap_2sri_ate <- function(dat, f_stage1, f_stage2,
                               treatment_var, resid_var,
                               n_boot = N_BOOT, seed = 42) {
  # ─── FIX 2026-05-22 ─────────────────────────────────────────────────────────
  # Two bugs in original:
  #   (1) Observation-level bootstrap → underestimates SE for clustered DHS data.
  #       Fix: cluster bootstrap (resample whole clusters).
  #   (2) glm() calls inside bootstrap loop dropped survey weights.
  #       Fix: pass weights = dat_boot$weight to both glm calls.
  # Requires `dat` to have a `cluster_id` column (added by caller).
  # ────────────────────────────────────────────────────────────────────────────
  set.seed(seed)
  ate_boots <- numeric(n_boot)

  if (!"cluster_id" %in% names(dat)) {
    warning("cluster_id missing from data; falling back to observation bootstrap")
    use_cluster_boot <- FALSE
  } else {
    use_cluster_boot <- TRUE
    cluster_ids_local <- unique(dat$cluster_id)
  }

  # Convert to plain data.frame ONCE outside loop — avoids tibble edge cases
  # with do.call(rbind, ...) in the cluster bootstrap below.
  dat_df <- as.data.frame(dat)

  for (b in seq_len(n_boot)) {
    if (use_cluster_boot) {
      sampled_cl <- sample(cluster_ids_local, length(cluster_ids_local), replace = TRUE)
      idx <- unlist(lapply(sampled_cl, function(cl) which(dat_df$cluster_id == cl)))
      dat_boot <- dat_df[idx, , drop = FALSE]
    } else {
      idx <- sample(nrow(dat_df), replace = TRUE)
      dat_boot <- dat_df[idx, , drop = FALSE]
    }

    # FIX A13 (2026-05-22): glm() evaluates `weights = ...` via non-standard
    # evaluation. Local variables (dat_boot$weight, w_boot) are not visible
    # to glm's NSE inside a function call. But unquoted column names ARE
    # visible because glm resolves them via `data` first. Since dat_boot has
    # a "weight" column, we pass `weights = weight` unquoted.
    # Also reset row.names to avoid duplicate-row-name issues after cluster
    # resampling.
    row.names(dat_boot) <- NULL

    tryCatch({
      s1_boot  <- suppressWarnings(glm(f_stage1, data = dat_boot,
                                       weights = weight,
                                       family  = binomial(link = "probit"),
                                       control = glm.control(maxit = 100)))
      # Reject only on catastrophic divergence (Inf/NaN coefs), not on convergence warning
      if (any(!is.finite(coef(s1_boot)))) stop("stage 1: non-finite coefficients")
      dat_boot[[resid_var]] <- dat_boot[[treatment_var]] - fitted(s1_boot)

      s2_boot  <- suppressWarnings(glm(f_stage2, data = dat_boot,
                                       weights = weight,
                                       family  = binomial(link = "probit"),
                                       control = glm.control(maxit = 100)))
      if (any(!is.finite(coef(s2_boot)))) stop("stage 2: non-finite coefficients")

      ate_b    <- compute_2sri_ate(s2_boot, treatment_var, resid_var, dat_boot)
      ate_boots[b] <- ate_b$ATE
    }, error = function(e) {
      ate_boots[b] <<- NA_real_
      # log the first few errors for diagnosis
      if (b <= 3) message(sprintf("  [boot err b=%d] %s", b, conditionMessage(e)))
    })
  }
  
  ate_boots <- ate_boots[!is.na(ate_boots)]
  list(
    boot_se    = sd(ate_boots),
    boot_lower = quantile(ate_boots, 0.025),
    boot_upper = quantile(ate_boots, 0.975),
    n_success  = length(ate_boots)
  )
}

# =============================================================================
# STEP 6: LOAD RBVP BASELINE ATES FOR COMPARISON
# =============================================================================

cat("STEP 6: Loading RBVP baseline for comparison\n")
cat("-----------------------------------\n")

rbvp_ate_file <- file.path(output_dir, "Formal_ATE_Results.csv")
if (file.exists(rbvp_ate_file)) {
  rbvp_ates <- read.csv(rbvp_ate_file, stringsAsFactors = FALSE)
  cat("✓ Loaded Formal_ATE_Results.csv\n")
} else {
  cat("⚠ Formal_ATE_Results.csv not found — RBVP comparison column will be NA\n")
  rbvp_ates <- data.frame(Year = years,
                          Csec_ATE = NA, ANC_ATE = NA,
                          stringsAsFactors = FALSE)
}

# =============================================================================
# STEP 7: MAIN 2SRI ANALYSIS LOOP
# =============================================================================

cat("\nSTEP 7: Running 2SRI models\n")
cat(strrep("=", 55), "\n\n")

# Output containers
results_2sri       <- data.frame()
full_stage1_2sri   <- list()
full_stage2_csec   <- list()
full_stage2_anc    <- list()

for (yr in years) {
  
  cat(strrep("=", 55), "\n")
  cat("YEAR:", yr, "\n")
  cat(strrep("=", 55), "\n\n")
  
  # --- Prepare data ---
  # FIX 2026-05-22: include cluster_id so the bootstrap can do proper
  # cluster resampling (was previously missing → observation bootstrap).
  dat_yr    <- df_run %>% filter(year == yr)
  vars_need <- c(outcome_var, endo_1, endo_2, iv_1, iv_2, final_controls,
                 "weight", "cluster_id")
  dat_clean <- dat_yr %>% select(all_of(vars_need))

  for (col in setdiff(names(dat_clean), c("weight", "cluster_id"))) {
    dat_clean[[col]] <- suppressWarnings(as.numeric(as.character(dat_clean[[col]])))
  }
  dat_clean <- dat_clean %>% filter(complete.cases(.))
  
  N   <- nrow(dat_clean)
  cat("N =", N, "\n\n")
  
  if (N < 100) {
    cat("⚠ Insufficient data. Skipping.\n\n")
    next
  }
  
  # ─────────────────────────────────────────────────────────────────────────
  # STAGE 1: First-stage probit for C-section + ANC (diagnostic only)
  # These are identical to Script 3's first-stage LPMs converted to probit.
  # ─────────────────────────────────────────────────────────────────────────
  cat("--- Stage 1: First-stage probit diagnostics ---\n")
  
  f_fs_csec <- as.formula(paste(endo_1, "~", iv_1, "+",
                                paste(final_controls, collapse = " + ")))
  f_fs_anc  <- as.formula(paste(endo_2, "~", iv_2, "+",
                                paste(final_controls, collapse = " + ")))
  
  fs_csec <- glm(f_fs_csec, data = dat_clean, family = binomial(link = "probit"))
  fs_anc  <- glm(f_fs_anc,  data = dat_clean, family = binomial(link = "probit"))
  
  # Store full first-stage coefficients (for supplementary table)
  fs_csec_summ <- coef(summary(fs_csec))
  full_stage1_2sri[[yr]] <- data.frame(
    Year     = yr,
    Stage    = "Stage1_Csection",
    Variable = rownames(fs_csec_summ),
    Coefficient = fs_csec_summ[, "Estimate"],
    SE       = fs_csec_summ[, "Std. Error"],
    Z_value  = fs_csec_summ[, "z value"],
    P_value  = fs_csec_summ[, "Pr(>|z|)"],
    stringsAsFactors = FALSE
  )
  
  # IV coefficient (for reporting strength)
  iv_csec_coef <- coef(summary(fs_csec))[iv_1, "Estimate"]
  iv_csec_p    <- coef(summary(fs_csec))[iv_1, "Pr(>|z|)"]
  iv_anc_coef  <- coef(summary(fs_anc)) [iv_2, "Estimate"]
  iv_anc_p     <- coef(summary(fs_anc)) [iv_2, "Pr(>|z|)"]
  
  cat("  C-section IV coef:", round(iv_csec_coef, 4),
      "(p =", format.pval(iv_csec_p, digits = 3), ")\n")
  cat("  ANC IV coef:", round(iv_anc_coef, 4),
      "(p =", format.pval(iv_anc_p, digits = 3), ")\n\n")
  
  # ─────────────────────────────────────────────────────────────────────────
  # 2SRI STAGE 1 (C-section): Second-stage probit for C-section → mortality
  # ─────────────────────────────────────────────────────────────────────────
  cat("--- 2SRI Stage 1: C-section → Mortality ---\n")
  
  # Generate residuals from C-section first-stage probit
  dat_clean[["resid_csec"]] <- get_probit_residuals(fs_csec)
  
  # Second-stage probit: outcome ~ csec + controls + resid_csec
  f_2sri_csec_s2 <- as.formula(paste(
    outcome_var, "~", endo_1, "+",
    paste(final_controls, collapse = " + "),
    "+ resid_csec"
  ))
  
  fit_2sri_csec <- tryCatch(
    glm(f_2sri_csec_s2, data = dat_clean, family = binomial(link = "probit")),
    error = function(e) {
      cat("  ✗ 2SRI C-section stage 2 failed:", e$message, "\n")
      NULL
    }
  )
  
  if (is.null(fit_2sri_csec)) {
    cat("  Skipping C-section 2SRI for this year.\n\n")
    ate_csec_2sri <- list(ATE = NA, ATE_SE = NA, ATE_lower = NA, ATE_upper = NA,
                          alpha = NA, gamma_v = NA)
    boot_csec     <- list(boot_se = NA, boot_lower = NA, boot_upper = NA, n_success = 0)
    csec_2sri_coef <- NA; csec_2sri_se <- NA; csec_2sri_p <- NA
    resid_csec_coef <- NA; resid_csec_p <- NA
  } else {
    # Compute ATE at v̂ = 0
    ate_csec_2sri <- tryCatch(
      compute_2sri_ate(fit_2sri_csec, endo_1, "resid_csec", dat_clean),
      error = function(e) {
        cat("  ⚠ ATE computation failed:", e$message, "\n")
        list(ATE = NA, ATE_SE = NA, ATE_lower = NA, ATE_upper = NA,
             alpha = NA, gamma_v = NA)
      }
    )
    
    # Bootstrap SEs
    cat("  Bootstrapping SEs (", N_BOOT, "reps)...\n")
    boot_csec <- tryCatch(
      bootstrap_2sri_ate(dat_clean, f_fs_csec, f_2sri_csec_s2,
                         endo_1, "resid_csec"),
      error = function(e) {
        cat("  ⚠ Bootstrap failed:", e$message, "\n")
        list(boot_se = NA, boot_lower = NA, boot_upper = NA, n_success = 0)
      }
    )
    
    csec_s2_summ   <- coef(summary(fit_2sri_csec))
    csec_2sri_coef <- csec_s2_summ[endo_1,      "Estimate"]
    csec_2sri_se   <- csec_s2_summ[endo_1,      "Std. Error"]
    csec_2sri_p    <- csec_s2_summ[endo_1,      "Pr(>|z|)"]
    resid_csec_coef <- csec_s2_summ["resid_csec", "Estimate"]
    resid_csec_p    <- csec_s2_summ["resid_csec", "Pr(>|z|)"]
    
    cat("  ✓ C-section 2SRI coef:", round(csec_2sri_coef, 4),
        "(p =", format.pval(csec_2sri_p, digits = 3), ")\n")
    cat("  ✓ Residual coef (endogeneity test):", round(resid_csec_coef, 4),
        "(p =", format.pval(resid_csec_p, digits = 3), ")\n")
    cat("  ✓ 2SRI ATE =", round(ate_csec_2sri$ATE * 100, 4), "pp",
        "[", round(boot_csec$boot_lower * 100, 4), ",",
        round(boot_csec$boot_upper * 100, 4), "] (bootstrap 95% CI)\n\n")
    
    # Store full stage-2 coefficients
    full_stage2_csec[[yr]] <- data.frame(
      Year        = yr,
      Stage       = "2SRI_Stage1_Csection",
      Variable    = rownames(csec_s2_summ),
      Coefficient = csec_s2_summ[, "Estimate"],
      SE          = csec_s2_summ[, "Std. Error"],
      Z_value     = csec_s2_summ[, "z value"],
      P_value     = csec_s2_summ[, "Pr(>|z|)"],
      stringsAsFactors = FALSE
    )
  }
  
  # ─────────────────────────────────────────────────────────────────────────
  # 2SRI STAGE 2 (ANC): Second-stage probit for ANC → mortality
  # Conditions on C-section status, matching RBVP Stage 2 structure.
  # ─────────────────────────────────────────────────────────────────────────
  cat("--- 2SRI Stage 2: ANC → Mortality (conditioning on C-section) ---\n")
  
  # First-stage probit for ANC (already have fs_anc from above)
  dat_clean[["resid_anc"]] <- get_probit_residuals(fs_anc)
  
  # Second-stage probit: outcome ~ anc + csec + controls + resid_anc
  f_2sri_anc_s2 <- as.formula(paste(
    outcome_var, "~", endo_2, "+", endo_1, "+",
    paste(final_controls, collapse = " + "),
    "+ resid_anc"
  ))
  
  fit_2sri_anc <- tryCatch(
    glm(f_2sri_anc_s2, data = dat_clean, family = binomial(link = "probit")),
    error = function(e) {
      cat("  ✗ 2SRI ANC stage 2 failed:", e$message, "\n")
      NULL
    }
  )
  
  if (is.null(fit_2sri_anc)) {
    cat("  Skipping ANC 2SRI for this year.\n\n")
    ate_anc_2sri   <- list(ATE = NA, ATE_SE = NA, ATE_lower = NA, ATE_upper = NA,
                           alpha = NA, gamma_v = NA)
    boot_anc       <- list(boot_se = NA, boot_lower = NA, boot_upper = NA, n_success = 0)
    anc_2sri_coef  <- NA; anc_2sri_se <- NA; anc_2sri_p <- NA
    resid_anc_coef <- NA; resid_anc_p <- NA
  } else {
    # ATE at v̂ = 0
    ate_anc_2sri <- tryCatch(
      compute_2sri_ate(fit_2sri_anc, endo_2, "resid_anc", dat_clean),
      error = function(e) {
        cat("  ⚠ ATE computation failed:", e$message, "\n")
        list(ATE = NA, ATE_SE = NA, ATE_lower = NA, ATE_upper = NA,
             alpha = NA, gamma_v = NA)
      }
    )
    
    # Bootstrap SEs
    # For Stage 2 we need the first stage for ANC only (csec already in data)
    f_fs_anc_stage2 <- as.formula(paste(endo_2, "~", iv_2, "+", endo_1, "+",
                                        paste(final_controls, collapse = " + ")))
    cat("  Bootstrapping SEs (", N_BOOT, "reps)...\n")
    boot_anc <- tryCatch(
      bootstrap_2sri_ate(dat_clean, f_fs_anc_stage2, f_2sri_anc_s2,
                         endo_2, "resid_anc"),
      error = function(e) {
        cat("  ⚠ Bootstrap failed:", e$message, "\n")
        list(boot_se = NA, boot_lower = NA, boot_upper = NA, n_success = 0)
      }
    )
    
    anc_s2_summ    <- coef(summary(fit_2sri_anc))
    anc_2sri_coef  <- anc_s2_summ[endo_2,     "Estimate"]
    anc_2sri_se    <- anc_s2_summ[endo_2,     "Std. Error"]
    anc_2sri_p     <- anc_s2_summ[endo_2,     "Pr(>|z|)"]
    resid_anc_coef <- anc_s2_summ["resid_anc", "Estimate"]
    resid_anc_p    <- anc_s2_summ["resid_anc", "Pr(>|z|)"]
    
    cat("  ✓ ANC 2SRI coef:", round(anc_2sri_coef, 4),
        "(p =", format.pval(anc_2sri_p, digits = 3), ")\n")
    cat("  ✓ Residual coef (endogeneity test):", round(resid_anc_coef, 4),
        "(p =", format.pval(resid_anc_p, digits = 3), ")\n")
    cat("  ✓ 2SRI ATE =", round(ate_anc_2sri$ATE * 100, 4), "pp",
        "[", round(boot_anc$boot_lower * 100, 4), ",",
        round(boot_anc$boot_upper * 100, 4), "] (bootstrap 95% CI)\n\n")
    
    # Store full stage-2 coefficients
    full_stage2_anc[[yr]] <- data.frame(
      Year        = yr,
      Stage       = "2SRI_Stage2_ANC",
      Variable    = rownames(anc_s2_summ),
      Coefficient = anc_s2_summ[, "Estimate"],
      SE          = anc_s2_summ[, "Std. Error"],
      Z_value     = anc_s2_summ[, "z value"],
      P_value     = anc_s2_summ[, "Pr(>|z|)"],
      stringsAsFactors = FALSE
    )
  }
  
  # ─────────────────────────────────────────────────────────────────────────
  # Retrieve RBVP ATEs for comparison
  # ─────────────────────────────────────────────────────────────────────────
  rbvp_row      <- rbvp_ates %>% filter(Year == yr)
  rbvp_csec_ate <- if (nrow(rbvp_row) > 0) rbvp_row$Csec_ATE[1] else NA
  rbvp_anc_ate  <- if (nrow(rbvp_row) > 0) rbvp_row$ANC_ATE[1]  else NA
  
  # ─────────────────────────────────────────────────────────────────────────
  # Sign consistency check
  # ─────────────────────────────────────────────────────────────────────────
  csec_sign_ok <- !is.na(ate_csec_2sri$ATE) && !is.na(rbvp_csec_ate) &&
    (sign(ate_csec_2sri$ATE) == sign(rbvp_csec_ate))
  anc_sign_ok  <- !is.na(ate_anc_2sri$ATE)  && !is.na(rbvp_anc_ate)  &&
    (sign(ate_anc_2sri$ATE)  == sign(rbvp_anc_ate))
  
  # ─────────────────────────────────────────────────────────────────────────
  # Collect results row
  # ─────────────────────────────────────────────────────────────────────────
  results_2sri <- rbind(results_2sri, data.frame(
    Year = yr,
    N    = N,
    
    # ── C-section ──────────────────────────────────────────────────────────
    Csec_RBVP_ATE            = rbvp_csec_ate,
    Csec_2SRI_Coef           = csec_2sri_coef,
    Csec_2SRI_SE             = csec_2sri_se,
    Csec_2SRI_P              = csec_2sri_p,
    Csec_2SRI_ATE            = ate_csec_2sri$ATE,
    Csec_2SRI_ATE_Boot_SE    = boot_csec$boot_se,
    Csec_2SRI_ATE_Boot_Lower = boot_csec$boot_lower,
    Csec_2SRI_ATE_Boot_Upper = boot_csec$boot_upper,
    Csec_Resid_Coef          = resid_csec_coef,      # endogeneity test
    Csec_Resid_P             = resid_csec_p,
    Csec_Signs_Consistent    = csec_sign_ok,
    
    # ── ANC ────────────────────────────────────────────────────────────────
    ANC_RBVP_ATE             = rbvp_anc_ate,
    ANC_2SRI_Coef            = anc_2sri_coef,
    ANC_2SRI_SE              = anc_2sri_se,
    ANC_2SRI_P               = anc_2sri_p,
    ANC_2SRI_ATE             = ate_anc_2sri$ATE,
    ANC_2SRI_ATE_Boot_SE     = boot_anc$boot_se,
    ANC_2SRI_ATE_Boot_Lower  = boot_anc$boot_lower,
    ANC_2SRI_ATE_Boot_Upper  = boot_anc$boot_upper,
    ANC_Resid_Coef           = resid_anc_coef,       # endogeneity test
    ANC_Resid_P              = resid_anc_p,
    ANC_Signs_Consistent     = anc_sign_ok,
    
    stringsAsFactors = FALSE
  ))
}

# =============================================================================
# STEP 8: BUILD SUMMARY COMPARISON TABLE
# =============================================================================

cat("\nSTEP 8: Building summary comparison table\n")
cat("-----------------------------------\n")

# Long-format table for supplementary: one row per year × treatment
summary_long <- data.frame()
for (i in seq_len(nrow(results_2sri))) {
  yr <- results_2sri$Year[i]
  N  <- results_2sri$N[i]
  
  summary_long <- rbind(summary_long, data.frame(
    Year      = yr,
    N         = N,
    Treatment = "C-section",
    RBVP_ATE  = results_2sri$Csec_RBVP_ATE[i],
    SRI_Coef  = results_2sri$Csec_2SRI_Coef[i],
    SRI_P     = results_2sri$Csec_2SRI_P[i],
    SRI_ATE   = results_2sri$Csec_2SRI_ATE[i],
    SRI_CI_Lo = results_2sri$Csec_2SRI_ATE_Boot_Lower[i],
    SRI_CI_Hi = results_2sri$Csec_2SRI_ATE_Boot_Upper[i],
    Resid_P   = results_2sri$Csec_Resid_P[i],
    Sign_Consistent = results_2sri$Csec_Signs_Consistent[i],
    stringsAsFactors = FALSE
  ))
  summary_long <- rbind(summary_long, data.frame(
    Year      = yr,
    N         = N,
    Treatment = "ANC 4+",
    RBVP_ATE  = results_2sri$ANC_RBVP_ATE[i],
    SRI_Coef  = results_2sri$ANC_2SRI_Coef[i],
    SRI_P     = results_2sri$ANC_2SRI_P[i],
    SRI_ATE   = results_2sri$ANC_2SRI_ATE[i],
    SRI_CI_Lo = results_2sri$ANC_2SRI_ATE_Boot_Lower[i],
    SRI_CI_Hi = results_2sri$ANC_2SRI_ATE_Boot_Upper[i],
    Resid_P   = results_2sri$ANC_Resid_P[i],
    Sign_Consistent = results_2sri$ANC_Signs_Consistent[i],
    stringsAsFactors = FALSE
  ))
}

# Full coefficient tables
full_coefs_2sri <- do.call(rbind, c(full_stage1_2sri, full_stage2_csec, full_stage2_anc))

# =============================================================================
# STEP 9: SAVE OUTPUTS
# =============================================================================

cat("\nSTEP 9: Saving outputs\n")
cat("-----------------------------------\n")

out <- function(df, name) {
  path <- file.path(output_dir, name)
  write.csv(df, path, row.names = FALSE)
  cat("✓ Saved:", name, "\n")
}

out(results_2sri,   "2SRI_Full_Results.csv")
out(summary_long,   "2SRI_Summary_Comparison.csv")
out(full_coefs_2sri,"2SRI_Full_Coefficients.csv")

# =============================================================================
# STEP 10: DIAGNOSTIC REPORT
# =============================================================================

cat("\n")
cat(strrep("=", 55), "\n")
cat("2SRI ROBUSTNESS RESULTS SUMMARY\n")
cat(strrep("=", 55), "\n\n")

cat("Sign consistency (key result for manuscript):\n")
cat("  RBVP ATE = primary estimate (bias-corrected)\n")
cat("  2SRI ATE = control function alternative estimator\n")
cat("  Consistent = same sign → result not an artefact\n\n")

print(summary_long %>%
        select(Year, Treatment, RBVP_ATE, SRI_ATE, Sign_Consistent) %>%
        mutate(across(c(RBVP_ATE, SRI_ATE), ~round(. * 100, 3))),
      row.names = FALSE)

cat("\n\nResidual coefficient significance (endogeneity confirmation):\n")
cat("  Significant resid_v in stage 2 = endogeneity confirmed\n")
cat("  (Wooldridge 2015 robust Hausman test interpretation)\n\n")

print(summary_long %>%
        select(Year, Treatment, Resid_P) %>%
        mutate(Endogeneity_Confirmed = ifelse(Resid_P < 0.05, "YES ***", "NO")),
      row.names = FALSE)

cat("\n\nInterpretation guide:\n")
cat("─────────────────────────────────────────────────────────\n")
cat("SIGN CONSISTENCY\n")
cat("  All 8 consistent → '2SRI corroborates RBVP sign-reversal\n")
cat("                       findings. C-section effects are protective\n")
cat("                       under both estimators in 2004 and 2022.'\n")
cat("  Some inconsistent → investigate that wave/treatment further\n\n")
cat("RESIDUAL COEFFICIENT\n")
cat("  Significant (p<0.05) → endogeneity confirmed. Naive probit\n")
cat("                          would be biased; correction necessary.\n")
cat("  Not significant     → endogeneity absent in this wave/treatment\n")
cat("                          (consistent with RBVP LR test result)\n\n")
cat("MAGNITUDE COMPARISON\n")
cat("  RBVP and 2SRI ATEs will differ because:\n")
cat("  - RBVP is a fully specified joint likelihood (efficient)\n")
cat("  - 2SRI is a control function (robust, less efficient)\n")
cat("  Focus on DIRECTION not magnitude for the robustness claim.\n")
cat("─────────────────────────────────────────────────────────\n\n")

cat("MANUSCRIPT PARAGRAPH TEMPLATE:\n")
cat("'As a distributional-assumption-free robustness check, we\n")
cat("re-estimated all treatment effects using two-stage residual\n")
cat("inclusion (2SRI; Terza et al. 2008; Terza 2018). 2SRI augments\n")
cat("the second-stage probit with the Stage 1 probit residuals,\n")
cat("thereby purging endogeneity without imposing bivariate normality\n")
cat("on the joint error structure (Wooldridge 2015). Bootstrap standard\n")
cat("errors (", N_BOOT, "replications) account for the two-step estimation.\n")
cat("Results are presented in Supplementary Table S-X. [Fill in]\n")
cat("signs consistent/inconsistent with RBVP across all eight\n")
cat("treatment-wave combinations, confirming that the sign-reversal\n")
cat("findings are not an artefact of distributional assumptions.'\n\n")

cat("✓ 2SRI robustness analysis complete!\n")
cat("  Output directory:", output_dir, "\n\n")
# =============================================================================
# PAKISTAN RBVP REPLICATION: THE REGIONAL SCISSORS PARADOX
# =============================================================================
library(dplyr)
library(GJRM)
library(pbivnorm)
library(mvtnorm)

cat("========================================\n")
cat("PAKISTAN DHS 2017-18 REPLICATION\n")
cat("========================================\n\n")

# 1. LOAD DATA
load("datasets/pakistan_dhs/PKBR71.RData")
df_raw <- PKBR71

# 2. HARMONIZATION & CLEANING
cat("Harmonizing variables...\n")

df <- df_raw %>%
  mutate(
    # Outcome: Standardized Child mortality (1 if died before 24 months, 0 otherwise)
    child_died = ifelse(!is.na(B7) & B7 < 24, 1, 0),
    
    # Treatments
    c_section_yes = ifelse(M17 == "Yes", 1, 0),
    
    # ANC 4+
    anc_visits = as.character(M14),
    anc_visits_num = suppressWarnings(as.numeric(anc_visits)),
    anc_4plus = ifelse(!is.na(anc_visits_num) & anc_visits_num >= 4, 1, 0),
    
    # Sector (M15)
    delivery_location = case_when(
      M15 %in% c("Respondent's home", "Other home") ~ 1, # Home
      M15 %in% c("Government hospital", "Rural health centre/Mother child health centre", 
                 "BHU(Basic Health Unit)", "Community midwife", "Other public sector") ~ 2, # Public
      M15 %in% c("Private hospital/clinic", "Other private medical sector") ~ 3, # Private
      TRUE ~ NA_real_
    ),
    
    # Confounders
    mother_education = case_when(
      V106 == "No education" ~ 0,
      V106 == "Primary" ~ 1,
      V106 == "Secondary" ~ 2,
      V106 == "Higher" ~ 3
    ),
    
    wealth_index = case_when(
      V190 == "Poorest" ~ 1,
      V190 == "Poorer" ~ 2,
      V190 == "Middle" ~ 3,
      V190 == "Richer" ~ 4,
      V190 == "Richest" ~ 5
    ),
    
    residence_urban = ifelse(V025 == "Urban", 1, 0),
    child_male = ifelse(B4 == "Male", 1, 0),
    mother_age = V012,
    
    # Sampling weight
    weight = V005 / 1000000,
    cluster_id = V001
  )

# [STANDARDIZED WINDOW] Filter for children born in last 3 years (0-35 months) 
# to ensure consistent observation exposure across waves/countries
df <- df %>% filter((V008 - B3) <= 35)

# 3. CREATE INSTRUMENTS (Leave-one-out cluster means)
cat("Creating cluster-level instruments...\n")

calc_iv <- function(data, var_name) {
  data %>%
    group_by(cluster_id) %>%
    mutate(
      sum_val = sum(!!sym(var_name), na.rm = TRUE),
      n_val = sum(!is.na(!!sym(var_name))),
      iv = (sum_val - ifelse(is.na(!!sym(var_name)), 0, !!sym(var_name))) / max(1, n_val - 1)
    ) %>%
    ungroup() %>%
    pull(iv)
}

df$IV_c_section_yes <- calc_iv(df, "c_section_yes")
df$IV_anc_4plus <- calc_iv(df, "anc_4plus")

# Clean for model
vars_model <- c("child_died", "c_section_yes", "anc_4plus", "IV_c_section_yes", "IV_anc_4plus",
                "mother_education", "wealth_index", "residence_urban", "child_male", "mother_age", 
                "delivery_location", "weight")

dat_clean <- df %>% select(all_of(vars_model)) %>% na.omit()

cat("Sample size for Pakistan RBVP:", nrow(dat_clean), "\n\n")

# 4. ATE FUNCTION (Phi2 approach)
compute_ate_group <- function(fit, treatment_var, indices) {
  summ <- summary(fit)
  
  # Extract linear predictors
  lp1_all <- as.numeric(predict(fit, type = "link", eq = 1))
  lp2_all <- as.numeric(predict(fit, type = "link", eq = 2))
  
  all_coefs <- coef(fit)
  theta_idx <- grep("theta", names(all_coefs), ignore.case = TRUE)
  rho <- if(length(theta_idx) > 0) tanh(all_coefs[theta_idx[1]]) else 0
  
  alpha <- summ$tableP2[treatment_var, "Estimate"]
  
  lp1 <- lp1_all[indices]
  lp2 <- lp2_all[indices]
  
  n <- length(lp1)
  if(n < 5) return(NA)

  ate_values <- sapply(1:n, function(i) {
    p1 <- pmvnorm(upper = c(lp2[i] + alpha, lp1[i]), corr = matrix(c(1, rho, rho, 1), 2, 2))[1]
    p0 <- pmvnorm(upper = c(lp2[i], lp1[i]), corr = matrix(c(1, rho, rho, 1), 2, 2))[1]
    return(p1 - p0)
  })
  
  return(mean(ate_values, na.rm = TRUE))
}

# 5. RUN RBVP MODEL (STAGE 1: C-SECTION)
cat("Running Stage 1: C-section endogeneity...\n")

f1_csec <- c_section_yes ~ IV_c_section_yes + mother_education + wealth_index + residence_urban + mother_age
f2_csec <- child_died ~ c_section_yes + mother_education + wealth_index + residence_urban + child_male + mother_age

fit_csec <- gjrm(list(f1_csec, f2_csec), 
                 data = dat_clean, 
                 weights = weight,
                 model = "B", margins = c("probit", "probit"))

ate_csec_all <- compute_ate_group(fit_csec, "c_section_yes", 1:nrow(dat_clean))
ate_csec_pub <- compute_ate_group(fit_csec, "c_section_yes", which(dat_clean$delivery_location == 2))
ate_csec_priv <- compute_ate_group(fit_csec, "c_section_yes", which(dat_clean$delivery_location == 3))

rho_csec <- tanh(coef(fit_csec)[grep("theta", names(coef(fit_csec)))[1]])

cat("\nRESULTS: PAKISTAN C-SECTION (2017-18)\n")
cat("------------------------------------\n")
cat("Overall ATE:", round(ate_csec_all, 6), "\n")
cat("Public ATE :", round(ate_csec_pub, 6), "\n")
cat("Private ATE:", round(ate_csec_priv, 6), "\n")
cat("Rho (Endogeneity):", round(rho_csec, 4), "\n\n")

# 6. RUN RBVP MODEL (STAGE 2: ANC 4+)
cat("Running Stage 2: ANC 4+ endogeneity...\n")

f1_anc <- anc_4plus ~ IV_anc_4plus + mother_education + wealth_index + residence_urban + mother_age
f2_anc <- child_died ~ anc_4plus + c_section_yes + mother_education + wealth_index + residence_urban + child_male + mother_age

fit_anc <- gjrm(list(f1_anc, f2_anc), 
                data = dat_clean, 
                weights = weight,
                model = "B", margins = c("probit", "probit"))

ate_anc_all <- compute_ate_group(fit_anc, "anc_4plus", 1:nrow(dat_clean))
rho_anc <- tanh(coef(fit_anc)[grep("theta", names(coef(fit_anc)))[1]])

cat("RESULTS: PAKISTAN ANC 4+ (2017-18)\n")
cat("------------------------------------\n")
cat("Overall ATE:", round(ate_anc_all, 6), "\n")
cat("Rho (Endogeneity):", round(rho_anc, 4), "\n\n")

# 7. SAVE RESULTS
pak_results <- data.frame(
  Country = "Pakistan",
  Year = "2017-18",
  Csec_ATE_Overall = ate_csec_all,
  Csec_ATE_Public = ate_csec_pub,
  Csec_ATE_Private = ate_csec_priv,
  Csec_Rho = rho_csec,
  ANC4_ATE_Overall = ate_anc_all,
  ANC4_Rho = rho_anc
)

write.csv(pak_results, "outputs/PAKISTAN_RBVP_RESULTS.csv", row.names = FALSE)
cat("✓ Results saved to outputs/PAKISTAN_RBVP_RESULTS.csv\n")

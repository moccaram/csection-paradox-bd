# =============================================================================
# DATA PIPELINE: PAKISTAN STANDARDIZATION (PHASE 2 PREP)
# =============================================================================
# Purpose: Harmonize the Pakistan 2017-18 (PDHS) microdata to exactly match 
#          the Bangladesh standardized schema (0-24 month mortality window, 
#          Public/Private sector decomposition, and socioeconomic variables).
# Output:  Pakistan_Standardized_0_24m.rds
# =============================================================================

library(dplyr)
library(here)
library(haven)

cat("========================================\n")
cat("BUILDING PAKISTAN MASTER DATASET\n")
cat("Harmonizing to South Asian Standard\n")
cat("========================================\n\n")

# Set directories
input_dir  <- here::here("data", "raw", "pakistan")
output_dir <- here::here("data", "processed")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Load Pakistan Microdata (PKBR71)
pk_file <- file.path(input_dir, "PKBR71.RData")
if(!file.exists(pk_file)) stop("Pakistan dataset not found.")

load(pk_file)
df_pk <- PKBR71
cat("✔ Loaded Pakistan DHS 2017-18: N =", nrow(df_pk), "\n")

# =============================================================================
# HARMONIZATION & STANDARDIZATION
# =============================================================================
cat("Standardizing variables and applying 0-24 month cohort filter...\n")

df_clean <- df_pk %>%
  mutate(
    # 1. Identifiers
    country = "Pakistan",
    year = 2017.5,
    cluster_id = as.numeric(V001),
    weight = as.numeric(V005) / 1000000,
    
    # 2. Outcomes & Treatments
    c_section_yes = ifelse(M17 == "Yes", 1, 0),
    child_died = ifelse(B5 == "No", 1, 0),
    
    # 3. Sector Decomposition
    sector = case_when(
      grepl("Government|Rural health|BHU|Community midwife|Other public", M15, ignore.case=TRUE) ~ "Public",
      grepl("Private hospital|Other private", M15, ignore.case=TRUE) ~ "Private",
      TRUE ~ "Home/Other"
    ),
    
    # 4. Controls
    residence_urban = ifelse(V025 == "Urban", 1, 0),
    wealth_score = case_when(
      grepl("Poorest", V190, ignore.case=TRUE) ~ 1,
      grepl("Poorer", V190, ignore.case=TRUE) ~ 2,
      grepl("Middle", V190, ignore.case=TRUE) ~ 3,
      grepl("Richer", V190, ignore.case=TRUE) ~ 4,
      grepl("Richest", V190, ignore.case=TRUE) ~ 5,
      TRUE ~ NA_real_
    ),
    mother_education = case_when(
      grepl("No education", V106, ignore.case=TRUE) ~ 0,
      grepl("Primary", V106, ignore.case=TRUE) ~ 1,
      grepl("Secondary", V106, ignore.case=TRUE) ~ 2,
      grepl("Higher", V106, ignore.case=TRUE) ~ 3,
      TRUE ~ NA_real_
    )
  )

# Calculate approximate age
if("B3" %in% names(df_clean) && "V008" %in% names(df_clean)) {
  df_clean <- df_clean %>%
    mutate(
      time_diff_months = as.numeric(V008) - as.numeric(B3),
      age_at_death_months = as.numeric(as.character(B7))
    )
}

# Apply 0-24 month truncation
if("time_diff_months" %in% names(df_clean)) {
  df_final <- df_clean %>%
    filter(!is.na(time_diff_months) & time_diff_months <= 35) %>%
    mutate(
      child_died = ifelse(child_died == 1 & !is.na(age_at_death_months) & age_at_death_months < 24, 1, 0)
    )
} else {
  df_final <- df_clean
}

# Export selection
vars_to_keep <- c("country", "year", "cluster_id", "weight", "child_died", 
                  "c_section_yes", "sector", "residence_urban", "wealth_score", 
                  "mother_education", "time_diff_months", "age_at_death_months")

df_export <- df_final %>% select(all_of(intersect(vars_to_keep, names(df_final))))

out_file <- file.path(output_dir, "Pakistan_Standardized_0_24m.rds")
saveRDS(df_export, out_file)

cat("✔ Standardization Complete.\n")
cat("Final Pakistan Sample (Standardized): N =", nrow(df_export), "\n")
cat("Saved to:", out_file, "\n")
cat("========================================\n")

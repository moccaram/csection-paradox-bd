# =============================================================================
# DATA PIPELINE: INDIA MACRO STANDARDIZATION (PHASE 2 PREP)
# =============================================================================
# Purpose: Extract and reshape state-level and national C-section rates
#          from the India NFHS-4 (2015-16) and NFHS-5 (2019-21) datasets
#          specifically tracking the Public vs. Private sector divergence.
# Output:  India_Macro_Standardized.rds
# =============================================================================

library(dplyr)
library(here)
library(tidyr)

cat("========================================\n")
cat("BUILDING INDIA MACRO DATASET\n")
cat("Extracting Sector Transitions\n")
cat("========================================\n\n")

# Set directories
input_dir  <- here::here("data", "raw", "india")
output_dir <- here::here("data", "processed")

# Load India Indicators
in_file <- file.path(input_dir, "India_NFHS_Indicators.csv")
if(!file.exists(in_file)) stop("India dataset not found.")

df_in <- read.csv(in_file, stringsAsFactors = FALSE)
cat("✔ Loaded India NFHS Indicators: N =", nrow(df_in), "\n")

# Filter for the relevant C-Section indicators
csec_indicators <- c(
  "Births delivered by caesarean section (%)",
  "Births in a private health facility that were delivered by caesarean section (%)",
  "Births in a public health facility that were delivered by caesarean section (%)"
)

df_csec <- df_in %>%
  filter(Indicator %in% csec_indicators) %>%
  mutate(
    Sector = case_when(
      grepl("private", Indicator, ignore.case=TRUE) ~ "Private",
      grepl("public", Indicator, ignore.case=TRUE) ~ "Public",
      TRUE ~ "Total"
    ),
    NFHS.5 = as.numeric(as.character(NFHS.5)),
    NFHS.4 = as.numeric(as.character(NFHS.4))
  )

# Reshape to Long Format to match South Asian Transition Plot needs
# NFHS-4 = ~2015.5
# NFHS-5 = ~2020.0
df_long <- df_csec %>%
  select(State, District, Sector, NFHS.4, NFHS.5) %>%
  pivot_longer(cols = c("NFHS.4", "NFHS.5"), names_to = "Wave", values_to = "Csec_Rate") %>%
  mutate(
    Year = ifelse(Wave == "NFHS.4", 2015.5, 2020.0),
    Country = "India"
  ) %>%
  filter(!is.na(Csec_Rate))

# Calculate National Averages (Simple unweighted average across districts for macro view)
# In a rigorous study, this would be population-weighted, but district-average 
# is sufficient for demonstrating the massive sector divergence in India.
df_national <- df_long %>%
  group_by(Country, Year, Sector) %>%
  summarise(
    Csec_Rate = mean(Csec_Rate, na.rm = TRUE),
    N_Districts = n(),
    .groups = "drop"
  )

# Export
out_file <- file.path(output_dir, "India_Macro_Standardized.rds")
saveRDS(list(Micro_Districts = df_long, National_Averages = df_national), out_file)

cat("✔ Standardization Complete.\n")
cat("Extracted C-section rates across", length(unique(df_long$District)), "districts.\n")
print(df_national)
cat("Saved to:", out_file, "\n")
cat("========================================\n")

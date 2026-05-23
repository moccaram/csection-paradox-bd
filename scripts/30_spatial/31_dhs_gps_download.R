# =============================================================================
# SPATIAL PHASE 1: AUTOMATED DHS GPS DOWNLOAD
# =============================================================================
# Purpose: Securely download the Geographic Data (GPS Clusters) for 
#          Bangladesh, Pakistan, and India using the 'rdhs' package.
# Note:    You MUST run this in an interactive R session (like RStudio)
#          so you can enter your DHS email, password, and approved Project Name.
# =============================================================================

# Install required packages if missing
if (!requireNamespace("rdhs", quietly = TRUE)) install.packages("rdhs")
if (!requireNamespace("sf", quietly = TRUE)) install.packages("sf")
if (!requireNamespace("dplyr", quietly = TRUE)) install.packages("dplyr")

library(rdhs)
library(here)
library(sf)
library(dplyr)

cat("========================================\n")
cat("SPATIAL PHASE 1: DHS GPS DOWNLOADER\n")
cat("========================================\n\n")

# Set directories
base_dir <- here::here()
spatial_dir <- file.path(base_dir, "datasets", "spatial_gps")
dir.create(spatial_dir, showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# 1. AUTHENTICATION & CONFIGURATION
# =============================================================================
cat("Setting up DHS configuration...\n")
cat("If you haven't configured rdhs before, it will prompt you for:\n")
cat("1. Your DHS registered email\n")
cat("2. Your approved Project Name\n")
cat("3. Your DHS password\n\n")

# Set up rdhs to cache downloaded files inside our project folder
set_rdhs_config(
  email = "moccaram@gmail.com",
  project = "Analyzing Verbal Autopsy Data from DHS Dataset: Insights into Mortality Patterns and Public Health in Low-Income Countries",
  config_path = "rdhs.json",
  cache_path = spatial_dir,
  global = FALSE
)

# =============================================================================
# 2. IDENTIFY THE GEOGRAPHIC (GPS) DATASETS
# =============================================================================
cat("Querying DHS API for approved GPS datasets...\n")

# We are looking for 'GE' (Geographic Data) file types for our specific waves
target_surveys <- data.frame(
  CountryCode = c("BD", "BD", "BD", "BD", "PK", "IA"),
  SurveyYear = c(2004, 2011, 2017, 2022, 2017, 2019),
  stringsAsFactors = FALSE
)

# Find the exact filenames on the DHS server
gps_datasets <- dhs_datasets(
  countryIds = unique(target_surveys$CountryCode),
  fileType = "GE",
  fileFormat = "flat" # Flat format is usually standard for GPS shapefiles
)

# Filter down to the specific years we need
needed_gps <- gps_datasets %>%
  filter(
    (CountryName == "Bangladesh" & SurveyYear %in% c(2004, 2011, 2017, 2022)) |
    (CountryName == "Pakistan" & SurveyYear == 2017) |
    (CountryName == "India" & SurveyYear >= 2019)
  )

if (nrow(needed_gps) == 0) {
  stop("Could not find the specified GPS datasets. Ensure your DHS account has access to Geographic Data.")
}

cat("Found", nrow(needed_gps), "matching GPS datasets on the DHS server.\n\n")

# =============================================================================
# 3. DOWNLOAD & CACHE
# =============================================================================
cat("Downloading datasets (this may take a few minutes depending on connection)...\n")

# The get_datasets() function downloads the ZIP files, extracts them, 
# and returns the local file paths.
local_paths <- get_datasets(dataset_filenames = needed_gps$FileName)

cat("\n========================================\n")
cat("DOWNLOAD COMPLETE!\n")
cat("========================================\n")
cat("Your GPS Shapefiles are now securely cached in:\n")
cat("  ", spatial_dir, "\n\n")
cat("They are ready to be merged with the Malaria Atlas travel times in Phase 2.\n")

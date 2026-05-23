# =============================================================================
# Dataset 2 + 4: DHS Geospatial Covariates + Facility/SPA Data
# Source: DHS Program via rdhs
# =============================================================================

suppressPackageStartupMessages({
  library(rdhs)
  library(dplyr)
})

BASE    <- here::here()
GEO_DIR <- file.path(BASE, "datasets", "dhs_geospatial")
FAC_DIR <- file.path(BASE, "datasets", "facility")
GPS_DIR <- file.path(BASE, "datasets", "spatial_gps")

for (d in c(GEO_DIR, FAC_DIR)) dir.create(d, showWarnings=FALSE, recursive=TRUE)

set_rdhs_config(
  email       = "moccaram@gmail.com",
  project     = "Analyzing Verbal Autopsy Data from DHS Dataset: Insights into Mortality Patterns and Public Health in Low-Income Countries",
  password    = "Hhaisenberg69*",
  config_path = file.path(BASE, "rdhs.json"),
  cache_path  = GPS_DIR,
  global      = FALSE
)

# =============================================================================
# 1. Geospatial Covariates (pre-linked rasters from DHS Spatial Repository)
# =============================================================================
cat("=== DHS Geospatial Covariates ===\n")
all_ds <- dhs_datasets(countryIds = c("BD","IA","PK"))

# Geospatial Covariates file type
geo_cov <- all_ds %>%
  filter(FileType == "Geospatial Covariates") %>%
  filter(
    (CountryName == "Bangladesh") |
    (CountryName == "India") |
    (CountryName == "Pakistan")
  ) %>%
  select(CountryName, SurveyYear, FileName, FileType) %>%
  arrange(CountryName, SurveyYear)

cat("Geospatial covariate files available:\n")
print(as.data.frame(geo_cov))

if (nrow(geo_cov) > 0) {
  # Only Bangladesh ones will download via rdhs; others need manual
  bd_geo <- geo_cov %>% filter(CountryName == "Bangladesh")
  if (nrow(bd_geo) > 0) {
    cat("\nDownloading Bangladesh geospatial covariates...\n")
    paths <- tryCatch(
      get_datasets(bd_geo$FileName, reformat = FALSE),
      error = function(e) { cat("Error:", conditionMessage(e), "\n"); list() }
    )
    for (nm in names(paths)) {
      dest <- file.path(GEO_DIR, basename(paths[[nm]]))
      if (!file.exists(dest)) file.copy(paths[[nm]], dest)
      cat("  Saved:", basename(dest), "\n")
    }
  }

  # Report what India/Pakistan geo covariates exist (manual download needed)
  other_geo <- geo_cov %>% filter(CountryName != "Bangladesh")
  if (nrow(other_geo) > 0) {
    cat("\nIndia/Pakistan geospatial covariates (require manual DHS download):\n")
    print(as.data.frame(other_geo))
    write.csv(other_geo, file.path(GEO_DIR, "MANUAL_DOWNLOAD_LIST_geospatial.csv"), row.names=FALSE)
  }
}

# =============================================================================
# 2. Facility / SPA (Service Provision Assessment) Data
# =============================================================================
cat("\n=== DHS SPA / Facility Data ===\n")

# Look for Facility file types
fac_ds <- all_ds %>%
  filter(FileType %in% c("Facility", "Service Availability Raw", "Provider",
                          "Staff/Provider Listing", "Fieldworker Questionnaire")) %>%
  filter(
    (CountryName == "Bangladesh") |
    (CountryName == "India") |
    (CountryName == "Pakistan")
  ) %>%
  select(CountryName, SurveyYear, FileName, FileType) %>%
  arrange(CountryName, SurveyYear)

cat("Facility/SPA files available:\n")
print(as.data.frame(fac_ds))

# Download Bangladesh SPA/facility (will work via rdhs)
bd_fac <- fac_ds %>% filter(CountryName == "Bangladesh",
                              FileType %in% c("Facility","Service Availability Raw"))

if (nrow(bd_fac) > 0) {
  cat("\nDownloading Bangladesh facility data...\n")
  paths <- tryCatch(
    get_datasets(bd_fac$FileName, reformat = FALSE),
    error = function(e) { cat("Error:", conditionMessage(e), "\n"); list() }
  )
  for (nm in names(paths)) {
    dest <- file.path(FAC_DIR, basename(paths[[nm]]))
    if (!file.exists(dest)) file.copy(paths[[nm]], dest)
    cat("  Saved:", basename(dest), "\n")
  }
}

# Save full list for reference
write.csv(fac_ds, file.path(FAC_DIR, "ALL_FACILITY_FILES_AVAILABLE.csv"), row.names=FALSE)
cat("\nFull facility file list saved to ALL_FACILITY_FILES_AVAILABLE.csv\n")

# =============================================================================
# Final inventory
# =============================================================================
cat("\n=== Geospatial Covariates dir ===\n")
writeLines(list.files(GEO_DIR))
cat("\n=== Facility dir ===\n")
writeLines(list.files(FAC_DIR))
cat("\nDone.\n")

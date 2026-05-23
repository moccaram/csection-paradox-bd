# =============================================================================
# MASTER DHS DOWNLOADER — South Asia C-Section Study
# =============================================================================

suppressPackageStartupMessages({
  library(rdhs)
  library(dplyr)
})

BASE    <- here::here()
BD_DIR  <- file.path(BASE, "datasets", "bangladesh")
IN_DIR  <- file.path(BASE, "datasets", "india")
PK_DIR  <- file.path(BASE, "datasets", "pakistan")
GPS_DIR <- file.path(BASE, "datasets", "spatial_gps")
CACHE   <- file.path(GPS_DIR, "datasets")   # where rdhs stores .rds files

for (d in c(BD_DIR, IN_DIR, PK_DIR, GPS_DIR, CACHE))
  dir.create(d, showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# 1. Authentication
# =============================================================================
cat("=== Authenticating with DHS ===\n")
set_rdhs_config(
  email       = "moccaram@gmail.com",
  project     = "Analyzing Verbal Autopsy Data from DHS Dataset: Insights into Mortality Patterns and Public Health in Low-Income Countries",
  password    = "Hhaisenberg69*",
  config_path = file.path(BASE, "rdhs.json"),
  cache_path  = GPS_DIR,
  global      = FALSE
)
cat("OK\n\n")

# =============================================================================
# 2. Discover all available datasets for our three countries
# =============================================================================
cat("=== Querying DHS API for BD / IA / PK datasets ===\n")
all_ds <- dhs_datasets(countryIds = c("BD", "IA", "PK"), fileFormat = "stata")
cat("Total records returned:", nrow(all_ds), "\n\n")

# Show all available BR and GE files so we know exactly what's accessible
cat("--- All Birth Recode files ---\n")
br_all <- all_ds %>% filter(FileType == "Births Recode") %>%
  select(CountryName, SurveyYear, FileName) %>% arrange(CountryName, SurveyYear)
print(as.data.frame(br_all))
cat("\n")

cat("--- All Geographic Data files ---\n")
ge_all <- all_ds %>% filter(grepl("Geographic|GPS|GE", FileType, ignore.case = TRUE)) %>%
  select(CountryName, SurveyYear, FileType, FileName) %>% arrange(CountryName, SurveyYear)
print(as.data.frame(ge_all))
cat("\n")

# =============================================================================
# 3. Define target files
# =============================================================================
BD_YEARS_BR <- c(2004, 2007, 2011, 2014, 2017, 2022)
IN_YEARS_BR <- c(1998, 2005, 2015, 2019)
PK_YEARS_BR <- c(2006, 2012, 2017, 2019)

GPS_YEARS   <- list(BD = BD_YEARS_BR, IA = IN_YEARS_BR, PK = PK_YEARS_BR)

target_br <- br_all %>%
  filter(
    (CountryName == "Bangladesh" & SurveyYear %in% BD_YEARS_BR) |
    (CountryName == "India"      & SurveyYear %in% IN_YEARS_BR) |
    (CountryName == "Pakistan"   & SurveyYear %in% PK_YEARS_BR)
  )

target_ge <- ge_all %>%
  filter(
    (CountryName == "Bangladesh" & SurveyYear %in% BD_YEARS_BR) |
    (CountryName == "India"      & SurveyYear %in% IN_YEARS_BR) |
    (CountryName == "Pakistan"   & SurveyYear %in% PK_YEARS_BR)
  )

cat("=== Targeted BR files (", nrow(target_br), ") ===\n")
print(as.data.frame(target_br))
cat("\n=== Targeted GE files (", nrow(target_ge), ") ===\n")
print(as.data.frame(target_ge))
cat("\n")

# =============================================================================
# 4. Download Birth Recode files (rdhs will skip already-cached)
# =============================================================================
copy_to_country <- function(paths_list, ds_meta) {
  dir_map <- c(Bangladesh = BD_DIR, India = IN_DIR, Pakistan = PK_DIR)
  for (i in seq_along(paths_list)) {
    nm   <- names(paths_list)[i]
    src  <- paths_list[[i]]
    cname <- ds_meta %>% filter(FileName == nm) %>% pull(CountryName)
    if (length(cname) == 0) next
    cname <- cname[1]
    dest_dir <- dir_map[cname]
    if (!is.na(dest_dir)) {
      dest <- file.path(dest_dir, basename(src))
      if (!file.exists(dest)) {
        file.copy(src, dest)
        cat("  Copied:", basename(src), "->", cname, "\n")
      } else {
        cat("  Exists:", basename(src), "\n")
      }
    }
  }
}

if (nrow(target_br) > 0) {
  cat("=== Downloading BR files ===\n")
  br_paths <- tryCatch(
    get_datasets(target_br$FileName, reformat = FALSE),
    error = function(e) { cat("Error:", conditionMessage(e), "\n"); list() }
  )
  if (length(br_paths) > 0) copy_to_country(br_paths, target_br)
}

# =============================================================================
# 5. Download GPS files
# =============================================================================
if (nrow(target_ge) > 0) {
  cat("\n=== Downloading GPS files ===\n")
  ge_paths <- tryCatch(
    get_datasets(target_ge$FileName, reformat = FALSE),
    error = function(e) { cat("Error:", conditionMessage(e), "\n"); list() }
  )
  cat("GPS files downloaded:", length(ge_paths), "\n")
  for (nm in names(ge_paths)) cat(" ", nm, "->", ge_paths[[nm]], "\n")
}

# =============================================================================
# 6. Copy already-cached Bangladesh BRs from rdhs cache
# =============================================================================
cat("\n=== Syncing cached Bangladesh BR files to BD_DIR ===\n")
bd_cached <- list.files(CACHE, pattern = "^BDBR.*\\.rds$", full.names = TRUE)
for (f in bd_cached) {
  dest <- file.path(BD_DIR, basename(f))
  if (!file.exists(dest)) { file.copy(f, dest); cat("  Copied:", basename(f), "\n") }
  else cat("  Exists:", basename(f), "\n")
}

# =============================================================================
# 7. Final inventory
# =============================================================================
cat("\n============================\n")
cat("FINAL INVENTORY\n")
cat("============================\n")
cat("Bangladesh:\n")
writeLines(list.files(BD_DIR))
cat("\nIndia:\n")
writeLines(list.files(IN_DIR))
cat("\nPakistan:\n")
writeLines(list.files(PK_DIR))
cat("\nGPS cache:\n")
writeLines(list.files(CACHE))

cat("\n=== DONE ===\n")

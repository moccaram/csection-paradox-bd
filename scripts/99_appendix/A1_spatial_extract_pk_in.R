# =============================================================================
# SPATIAL PHASE 5: EXTRACT PAKISTAN AND INDIA GPS COVARIATES
# =============================================================================
# Purpose: Merge the downloaded GPS ZIP files with the standardized regional
#          microdata and extract travel times from the Malaria Atlas Project.
# =============================================================================

library(dplyr)
library(here)
library(sf)
library(malariaAtlas)
library(terra)

cat("========================================\n")
cat("SPATIAL PHASE 5: REGIONAL GPS MERGE\n")
cat("Pakistan & India\n")
cat("========================================\n\n")

# NOTE: The drive path has '1' appended in the user's latest path
base_dir <- here::here()
spatial_dir <- file.path(base_dir, "datasets", "spatial_gps", "datasets")
results_dir <- file.path(base_dir, "results")
data_prep_dir <- file.path(results_dir, "data_preparation")

# Function to extract shapefile from DHS ZIP robustly
extract_dhs_shp <- function(zip_file) {
  temp_dir <- tempfile()
  dir.create(temp_dir)
  unzip(zip_file, exdir = temp_dir)
  # ignore.case is crucial for Linux file systems
  shp_file <- list.files(temp_dir, pattern = "\\.shp$", ignore.case = TRUE, full.names = TRUE)
  
  if(length(shp_file) > 0) {
    return(st_read(shp_file[1], quiet = TRUE))
  } else {
    stop("No shapefile found in ", zip_file)
  }
}

# =============================================================================
# 1. PAKISTAN (2017-18)
# =============================================================================
cat("Processing Pakistan (2017-18)...\n")
pk_data_file <- file.path(data_prep_dir, "Pakistan_Standardized_0_24m.rds")

if(file.exists(pk_data_file)) {
  pk_df <- readRDS(pk_data_file)
  pk_zip <- file.path(spatial_dir, "PKGE71FL.ZIP")
  
  if(file.exists(pk_zip)) {
    cat("  ✔ Found Pakistan GPS ZIP. Extracting...\n")
    pk_sf <- extract_dhs_shp(pk_zip)
    
    # Join on DHSCLUST
    pk_merged <- pk_df %>%
      left_join(
        pk_sf %>% select(DHSCLUST, LATNUM, LONGNUM),
        by = c("cluster_id" = "DHSCLUST")
      ) %>%
      filter(!is.na(LATNUM) & LATNUM != 0) %>%
      st_as_sf(coords = c("LONGNUM", "LATNUM"), crs = 4326, remove = FALSE)
    
    cat("  ✔ Merged GPS Coordinates. Attempting MAP Travel Time Extraction...\n")
    
    tryCatch({
      # Download the specific Healthcare Travel Time surface for Pakistan bounding box
      pk_shp_bounds <- getShp(ISO = "PAK", admin_level = "admin0")
      pk_raster <- getRaster(
        dataset_id = "Accessibility__202001_Global_Motorized_Travel_Time_to_Healthcare",
        shp = pk_shp_bounds
      )
      
      # Extract
      pk_terra <- rast(pk_raster)
      pk_merged <- st_transform(pk_merged, crs(pk_terra))
      ext_times <- terra::extract(pk_terra, vect(pk_merged))
      pk_merged$travel_time_to_hospital <- ext_times[, 2]
      
      cat("  ✔ Pakistan Travel Time Extraction Complete.\n")
    }, error = function(e) {
      cat("  ⚠ Malaria Atlas API Error for Pakistan (skipping travel time):\n    ", e$message, "\n")
    })
    
    # Save the spatially-enabled Pakistan dataset
    saveRDS(pk_merged, file.path(results_dir, "Pakistan_Spatial_Master.rds"))
    cat("  ✔ Pakistan Spatial Master Saved.\n\n")
    
  } else {
    cat("  ⚠ PKGE71FL.ZIP not found in", spatial_dir, "\n\n")
  }
} else {
  cat("  ⚠ Pakistan standardized microdata not found.\n\n")
}

# =============================================================================
# 2. INDIA (2015-16 and 2019-21)
# =============================================================================
cat("Processing India (NFHS-4 and NFHS-5)...\n")
in_zip_4 <- file.path(spatial_dir, "IAGE71FL.ZIP")
in_zip_5 <- file.path(spatial_dir, "IAGE7AFL.ZIP")

in_sf_4 <- NULL
in_sf_5 <- NULL

if(file.exists(in_zip_4)) {
  cat("  ✔ Found India NFHS-4 GPS ZIP. Extracting...\n")
  in_sf_4 <- extract_dhs_shp(in_zip_4)
} else {
  cat("  ⚠ IAGE71FL.ZIP (NFHS-4) not found.\n")
}

if(file.exists(in_zip_5)) {
  cat("  ✔ Found India NFHS-5 GPS ZIP. Extracting...\n")
  in_sf_5 <- extract_dhs_shp(in_zip_5)
} else {
  cat("  ⚠ IAGE7AFL.ZIP (NFHS-5) not found.\n")
}

if(!is.null(in_sf_4) || !is.null(in_sf_5)) {
  saveRDS(list(NFHS4 = in_sf_4, NFHS5 = in_sf_5), file.path(results_dir, "India_GPS_Clusters_Raw.rds"))
  cat("  ✔ India GPS Shapefiles Extracted and Saved.\n")
}

cat("\n========================================\n")
cat("SPATIAL PHASE 5 COMPLETE\n")
cat("========================================\n")

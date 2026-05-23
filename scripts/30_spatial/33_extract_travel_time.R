# =============================================================================
# SPATIAL PHASE 3: EXTRACT TRAVEL TIME (MALARIA ATLAS PROJECT)
# =============================================================================
# Purpose: Download the "Global map of travel time to healthcare facilities" 
#          raster for Bangladesh and extract the minutes for each DHS cluster.
#          This provides our stable Supply-Side Instrument.
# Output:  Bangladesh_Spatial_TravelTime.rds
# =============================================================================

library(dplyr)
library(here)
library(sf)
library(malariaAtlas)
library(terra)

cat("========================================\n")
cat("SPATIAL PHASE 3: TRAVEL TIME EXTRACTION\n")
cat("========================================\n\n")

# Set directories
base_dir <- here::here()
results_dir <- file.path(base_dir, "results")

# 1. LOAD SPATIAL MASTER DATA
cat("Loading Spatially-Enabled Master Dataset...\n")
spatial_file <- file.path(results_dir, "Bangladesh_Spatial_Master.rds")
if(!file.exists(spatial_file)) stop("Spatial Master dataset not found!")

df_sf <- readRDS(spatial_file)
cat("✔ Data loaded: N =", nrow(df_sf), "clusters with GPS.\n\n")

# 2. DOWNLOAD MALARIA ATLAS RASTER
cat("Querying Malaria Atlas Project API...\n")
cat("Downloading Travel Time Raster for Bangladesh (this may take a moment)...\n")

tryCatch({
  # Download the specific Healthcare Travel Time surface for Bangladesh bounding box
  bd_shp <- getShp(ISO = "BGD", admin_level = "admin0")
  travel_raster <- getRaster(
    dataset_id = "Accessibility__202001_Global_Motorized_Travel_Time_to_Healthcare",
    shp = bd_shp
  )
  cat("✔ Raster downloaded successfully.\n\n")
  
  # Convert RasterLayer to terra SpatRaster for fast extraction
  # (No longer needed, getRaster returns SpatRaster directly in newer versions)
  
  # 3. EXTRACT VALUES
  cat("Extracting travel times for each DHS cluster...\n")
  
  # Ensure CRS match
  df_sf <- st_transform(df_sf, crs(travel_raster))
  
  # Extract
  extracted_times <- terra::extract(travel_raster, vect(df_sf))
  
  # Bind back to the main dataset
  # Extract outputs a dataframe where the second column is the raster value
  df_sf$travel_time_to_hospital <- extracted_times[, 2]
  
  cat("✔ Extraction complete.\n")
  
  # Handle missing/ocean points
  missing_tt <- sum(is.na(df_sf$travel_time_to_hospital))
  cat("  Clusters missing travel time (e.g. islands/ocean jitter):", missing_tt, "\n\n")
  
  # 4. EXPORT
  out_file <- file.path(results_dir, "Bangladesh_Spatial_TravelTime.rds")
  saveRDS(df_sf, out_file)
  
  cat("========================================\n")
  cat("SPATIAL PHASE 3 COMPLETE\n")
  cat("========================================\n")
  cat("Saved final augmented dataset to:\n")
  cat("  ", out_file, "\n")
  cat("You now have a perfect, stable supply-side instrument!\n")
  
}, error = function(e) {
  cat("⚠ ERROR during Malaria Atlas extraction:\n")
  cat(e$message, "\n")
  cat("\nThe MAP API might be down or experiencing high traffic. Please try again later.\n")
})

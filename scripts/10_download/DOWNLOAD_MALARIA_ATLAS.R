# =============================================================================
# Malaria Atlas Project — Travel Time Rasters for South Asia
# Saves as .rds (terra SpatRaster) — use terra::rast(readRDS(file)) to load
# =============================================================================

suppressPackageStartupMessages({
  library(malariaAtlas)
  library(terra)
  library(sf)
})

OUT <- here::here("data", "raw", "malaria_atlas")
dir.create(OUT, showWarnings=FALSE, recursive=TRUE)

cat("=== Malaria Atlas — Travel Time Download ===\n\n")

# South Asia bounding box
sa_sf <- st_as_sf(st_sfc(
  st_polygon(list(rbind(c(60,5), c(97,5), c(97,38), c(60,38), c(60,5)))),
  crs = 4326
))
sa_sp <- as(sa_sf, "Spatial")

LAYERS <- list(
  list(id="Explorer__2020_motorized_travel_time_to_healthcare",   label="motorized_travel_healthcare_2020"),
  list(id="Explorer__2020_walking_only_travel_time_to_healthcare", label="walking_travel_healthcare_2020"),
  list(id="Explorer__2015_accessibility_to_cities_v1.0",           label="travel_time_cities_2015"),
  list(id="Explorer__2020_motorized_friction_surface",              label="friction_motorized_2020"),
  list(id="Explorer__2015_friction_surface_v1_Decompressed",        label="friction_2015")
)

for (layer in LAYERS) {
  dest_rds <- file.path(OUT, paste0("SouthAsia_", layer$label, ".rds"))
  dest_tif <- file.path(OUT, paste0("SouthAsia_", layer$label, ".tif"))

  if ((file.exists(dest_rds) || file.exists(dest_tif)) &&
      max(c(file.size(dest_rds), file.size(dest_tif)), na.rm=TRUE) > 100000) {
    cat("Already exists:", layer$label, "\n"); next
  }

  cat("Downloading:", layer$label, "...\n")
  r <- tryCatch(
    suppressMessages(getRaster(dataset_id = layer$id, shp = sa_sp)),
    error = function(e) { cat("  Error:", conditionMessage(e), "\n"); NULL }
  )

  if (!is.null(r) && terra::hasValues(r)) {
    # Try saving as GeoTIFF first (preferred for spatial workflows)
    saved_tif <- tryCatch({
      # Force values into memory then write
      terra::values(r)  # ensure loaded
      terra::writeRaster(r, dest_tif, overwrite=TRUE, datatype="FLT4S")
      cat("  Saved TIF:", basename(dest_tif), "(", round(file.size(dest_tif)/1e6,1), "MB)\n")
      TRUE
    }, error = function(e) {
      cat("  TIF error:", conditionMessage(e), "\n"); FALSE
    })

    if (!saved_tif) {
      # Fallback: save as RDS
      saveRDS(r, dest_rds)
      cat("  Saved RDS:", basename(dest_rds), "(", round(file.size(dest_rds)/1e6,1), "MB)\n")
    }
  } else {
    cat("  No values in raster\n")
  }
  Sys.sleep(1)
}

cat("\n=== Files in malaria_atlas/ ===\n")
files <- list.files(OUT, pattern="\\.(tif|rds)$")
for (f in files) cat(" ", f, "(", round(file.size(file.path(OUT,f))/1e6,1), "MB)\n")
cat("\nDone.\n")

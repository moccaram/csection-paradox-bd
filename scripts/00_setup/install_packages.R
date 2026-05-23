# =============================================================================
# install_packages.R
# Single source of truth for R package dependencies of csection-paradox-bd.
# Run once before executing any pipeline scripts.
#
# Tested with R 4.3.x on Linux. Spatial dependencies (sf, terra) require
# system libraries: GDAL >= 3.0, PROJ >= 6.0, GEOS >= 3.7.
#   Ubuntu/Debian: sudo apt install libgdal-dev libproj-dev libgeos-dev libudunits2-dev
#   macOS (Homebrew): brew install gdal proj geos udunits
# =============================================================================

repos <- c(CRAN = "https://cloud.r-project.org")

# Core pipeline packages (causal estimation + diagnostics)
core_packages <- c(
  "GJRM",        # Recursive bivariate probit (Marra & Radice)
  "AER",         # 2SLS / ivreg
  "sandwich",    # Cluster-robust standard errors
  "lmtest",      # coeftest with custom vcov
  "pbivnorm",    # Bivariate normal CDF for RBVP ATE
  "boot",        # Cluster bootstrap utility
  "dplyr",       # Data manipulation
  "tidyr",       # Reshape
  "ggplot2",     # Plotting
  "here",        # Portable paths
  "readr"        # Fast CSV I/O
)

# Phase D modern inference packages
phase_d_packages <- c(
  "EValue",      # VanderWeele & Ding (2017) E-value
  "sensemakr"    # Cinelli & Hazlett (2020) OVB sensitivity
)

# Spatial packages (optional — needed only for scripts/30_spatial/ and
# scripts/10_download/DOWNLOAD_MALARIA_ATLAS.R)
spatial_packages <- c(
  "sf",          # Simple features
  "terra",       # Raster I/O
  "rdhs",        # DHS API wrapper (requires DHS account)
  "malariaAtlas",# MAP raster downloads
  "lme4"         # Multilevel models
)

cat("Installing core packages...\n")
install.packages(setdiff(core_packages, rownames(installed.packages())), repos = repos)

cat("\nInstalling Phase D packages...\n")
install.packages(setdiff(phase_d_packages, rownames(installed.packages())), repos = repos)

cat("\nInstalling spatial packages (optional — comment out if not needed)...\n")
tryCatch({
  install.packages(setdiff(spatial_packages, rownames(installed.packages())), repos = repos)
}, error = function(e) {
  message("Spatial packages failed to install. Spatial scripts in 30_spatial/ ",
          "will not run, but core causal pipeline will. Reason: ",
          conditionMessage(e))
})

cat("\nDone. Verifying installation...\n")
all_packages <- c(core_packages, phase_d_packages, spatial_packages)
installed <- rownames(installed.packages())
missing <- setdiff(all_packages, installed)
if (length(missing) == 0) {
  cat("All packages installed.\n")
} else {
  cat("MISSING (install manually):\n  ", paste(missing, collapse = "\n  "), "\n", sep = "")
}

cat("\nR session info:\n")
print(sessionInfo())

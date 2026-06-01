# =============================================================================
# _common.R — auto-loaded by every chapter
# Centralizes package loading, ggplot2 theming, knitr defaults, and reusable
# helpers. Each chapter opens with:
#
#   source(here::here("_common.R"))
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(readr)
  library(knitr)
  library(here)
  library(scales)
})

# Source all reusable functions under R/
helper_files <- list.files(here::here("R"), pattern = "\\.R$", full.names = TRUE)
for (f in helper_files) source(f, local = FALSE)

# Global knitr chunk options
knitr::opts_chunk$set(
  fig.width  = 8,
  fig.height = 5,
  fig.align  = "center",
  dpi        = 200,
  out.width  = "100%",
  echo       = TRUE,
  warning    = FALSE,
  message    = FALSE,
  cache      = TRUE
)

# Apply the global ggplot2 theme defined in R/theme_csection.R
if (exists("theme_csection")) ggplot2::theme_set(theme_csection())

# =============================================================================
# theme_csection.R — ggplot2 theme + palette used throughout the book
# =============================================================================

#' Global ggplot2 theme for the book
#'
#' Built on `theme_minimal` with tighter typography, subdued caption color,
#' and a bold-title convention matched to the chapter prose.
#'
#' @param base_size Numeric. Base font size for axis text and labels.
#' @return A `ggplot2::theme` object.
theme_csection <- function(base_size = 13) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.title       = ggplot2::element_text(face = "bold"),
      plot.subtitle    = ggplot2::element_text(color = "gray30"),
      plot.caption     = ggplot2::element_text(color = "gray50", hjust = 0),
      legend.position  = "top",
      legend.title     = ggplot2::element_text(face = "bold", size = base_size - 2),
      panel.grid.minor = ggplot2::element_blank()
    )
}

#' Brand palette for the book
#'
#' Aligned with custom.scss so figure colors match the site styling.
csec_palette <- c(
  primary   = "#c0392b",  # C-section signal red
  secondary = "#2c3e50",  # diagnostic prose
  success   = "#27ae60",  # robust signals
  warning   = "#e67e22",  # fragile / weak
  info      = "#2980b9",  # sensemakr blue
  muted     = "#7f8c8d"   # comparison / appendix
)

#' Named country colors for South Asia comparisons
csec_country_palette <- c(
  Bangladesh = "#c0392b",
  India      = "#7f8c8d",
  Pakistan   = "#95a5a6"
)

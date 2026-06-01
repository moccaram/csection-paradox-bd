# =============================================================================
# format_helpers.R — formatting + kable wrappers for tables in chapters
# =============================================================================

#' Format a proportion as a percentage with one decimal
#' @param x Numeric in [0,1]
pct1 <- function(x) sprintf("%.1f%%", 100 * x)

#' Format a percentage-point effect (small, signed)
#' @param x Numeric on the percentage-point scale (e.g. -1.51)
fmt_pp <- function(x, digits = 2) sprintf("%+.*f pp", digits, x)

#' Format a p-value with smart thresholds
fmt_p <- function(p, eps = 1e-4) {
  ifelse(is.na(p), "—",
    ifelse(p < eps, sprintf("< %.0e", eps),
      ifelse(p < 0.001, sprintf("%.1e", p),
        sprintf("%.3f", p))))
}

#' Format a 95% confidence interval on the percentage-point scale
#' @param lo,hi Numeric on the percentage-point scale
fmt_ci_pp <- function(lo, hi, digits = 2) {
  sprintf("[%+.*f, %+.*f]", digits, lo, digits, hi)
}

#' Kable wrapper with sensible defaults for HTML/PDF book chapters
book_table <- function(df, caption = NULL, digits = 3, align = NULL, ...) {
  knitr::kable(df, caption = caption, digits = digits, align = align,
               format.args = list(big.mark = ","), ...)
}

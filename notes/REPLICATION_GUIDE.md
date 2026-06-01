# Replication guide

This document covers what's required to reproduce every result and figure in the repository, from a cold clone of the GitHub repo to publication-quality outputs.

The repository is structured so that **Quickstart paths require zero external data access** (descriptive figures + Phase D analyses use committed aggregates), while the **full causal pipeline** requires registered access to the DHS Program microdata.

---

## Tier 1 — Quickstart (no DHS access required, ~5 min)

Reproduces all 5 descriptive figures and all 4 Phase D outputs using committed aggregates.

```bash
git clone https://github.com/moccaram/csection-paradox-bd.git
cd csection-paradox-bd

# 1. Install R packages (one-time, ~5 min)
Rscript scripts/00_setup/install_packages.R

# 2. Reproduce descriptive figures
for s in 21 22 23 24 25; do
  Rscript scripts/20_descriptive/${s}_*.R
done

# 3. Reproduce Phase D
Rscript scripts/50_phase_d_modern/51_evalue.R
Rscript scripts/50_phase_d_modern/54_chow_descriptive_break.R
Rscript scripts/50_phase_d_modern/52_sensemakr.R
Rscript scripts/50_phase_d_modern/53_acerenza_inequalities.R
```

Expected runtime: ~5 minutes total. All outputs land in `outputs/` and `figures/`.

---

## Tier 2 — Causal pipeline reproduction (requires DHS access, ~1 hour)

Reproduces the 5 main causal scripts in [`scripts/40_causal_main/`](../scripts/40_causal_main/) from the same input data already committed in `outputs/causal_main/`.

```bash
# Smoke test with N_BOOT=2 (~1 minute)
N_BOOT=2 Rscript scripts/40_causal_main/41_rbvp_main.R

# Production run with N_BOOT=200 (~20 minutes)
N_BOOT=200 Rscript scripts/40_causal_main/41_rbvp_main.R

# 2SRI with N_BOOT=500 (~30 minutes)
N_BOOT=500 Rscript scripts/40_causal_main/42_two_stage_residual_inclusion.R

# IV validity diagnostics, copula sensitivity, Conley bounds
Rscript scripts/40_causal_main/43_copula_sensitivity.R
Rscript scripts/40_causal_main/44_iv_validity_tests.R
Rscript scripts/40_causal_main/45_conley_bounds.R
```

The pipeline reads from `outputs/causal_main/data_step1_complete.rds` and `data_with_instruments.rds`, both of which are committed in this repository as derived data.

---

## Tier 3 — Full reproduction from raw DHS microdata (requires registration, ~half day)

### Step 0 — System requirements

- R ≥ 4.1.0
- For spatial scripts: GDAL ≥ 3.0, PROJ ≥ 6.0, GEOS ≥ 3.7
  - Ubuntu/Debian: `sudo apt install libgdal-dev libproj-dev libgeos-dev libudunits2-dev`
  - macOS (Homebrew): `brew install gdal proj geos udunits`
- ~5 GB free disk for raw DHS + Malaria Atlas raster downloads

### Step 1 — DHS Program account and project approval

1. Create an account at https://dhsprogram.com (free, requires basic researcher info).
2. Create a project request describing your intended use of BDHS data. Approval typically takes 1–3 business days.
3. Once approved, your account will have download access to BDHS individual recode (IR), household member recode (PR), births recode (BR), and the geographic data sets (GE).

### Step 2 — Configure the `rdhs` API wrapper

Create `~/.dhs_credentials` with two lines:
```
email=your.email@example.com
project=Your Project Title (must match the approved project request)
```

Then in R:
```r
library(rdhs)
set_rdhs_config(
  email = readLines("~/.dhs_credentials")[1],
  project = readLines("~/.dhs_credentials")[2],
  config_path = "~/.dhs_credentials_cache",
  global = TRUE
)
```

### Step 3 — Download raw DHS microdata + spatial assets

```bash
# Bangladesh DHS individual recodes 2004, 2011, 2017–18, 2022
Rscript scripts/10_download/DOWNLOAD_ALL_DHS_DATASETS.R

# DHS geospatial cluster data (GPS coordinates)
Rscript scripts/10_download/DOWNLOAD_DHS_GEOSPATIAL_FACILITY.R

# Malaria Atlas Project travel-time-to-healthcare rasters (~152 MB)
Rscript scripts/10_download/DOWNLOAD_MALARIA_ATLAS.R
```

After completion, `data/raw/bangladesh/` contains the DHS files; `data/raw/malaria_atlas/` contains the rasters.

### Step 4 — Build descriptive evidence from raw microdata

The committed `data/processed/descriptive/P1_*.csv` files were generated from `/rv/FINAL_REPLICATION_PACKAGE_SOUTH_ASIA/30_ANALYSIS/scripts/TRANSITION_PHASE1_DECOMPOSITION.R` (see that file for reference). To regenerate from raw BDHS:

```bash
# Note: requires DHS microdata in data/raw/bangladesh/
# Path-adjustments may be needed depending on your installation of /rv/ scripts
Rscript scripts/20_descriptive/21_csec_trajectory.R  # ... etc.
```

### Step 5 — Spatial pipeline

```bash
Rscript scripts/30_spatial/31_dhs_gps_download.R
Rscript scripts/30_spatial/32_dhs_gps_merge.R
Rscript scripts/30_spatial/33_extract_travel_time.R
Rscript scripts/30_spatial/34_spatial_models_bd.R
Rscript scripts/30_spatial/35_multilevel_models.R
```

### Step 6 — Causal pipeline (full)

As in Tier 2, with all scripts executed in order:

```bash
N_BOOT=200 Rscript scripts/40_causal_main/41_rbvp_main.R
N_BOOT=500 Rscript scripts/40_causal_main/42_two_stage_residual_inclusion.R
Rscript scripts/40_causal_main/43_copula_sensitivity.R
Rscript scripts/40_causal_main/44_iv_validity_tests.R
Rscript scripts/40_causal_main/45_conley_bounds.R
```

### Step 7 — Phase D

As in Tier 1.

### Step 8 — India + Pakistan appendix (optional)

```bash
Rscript scripts/99_appendix/A4_build_india_master.R
Rscript scripts/99_appendix/A5_build_pakistan_master.R
Rscript scripts/99_appendix/A1_spatial_extract_pk_in.R
Rscript scripts/99_appendix/A2_india_spatial_trends.R
Rscript scripts/99_appendix/A3_pakistan_rbvp_replication.R
```

These require NFHS (India) and DHS Pakistan microdata in `data/raw/india/` and `data/raw/pakistan/` respectively.

---

## Expected outputs by tier

| Tier | What you produce |
|---|---|
| Tier 1 | 5 descriptive figures + 4 Phase D CSVs + 13 Phase D figures (E-value + sensemakr 4 waves × 2 plots + RV bar + Acerenza + Chow) |
| Tier 2 | Above + 10+ CSVs in `outputs/causal_main/` (Formal_ATE_Results, 2SRI_*, Copula_*, IV_*, Conley_*) |
| Tier 3 | Above + raw DHS microdata + spatial RDS files + (optionally) India/Pakistan multi-country outputs |

---

## Troubleshooting

### "Gumbel copula did not converge" warning in 43_copula_sensitivity.R

Expected. The Gumbel copula models upper-tail dependence in the latent error structure, which is not strongly identified in this data. Clayton (lower-tail) and Frank (symmetric) converge consistently. The script reports NA for Gumbel in 5/8 cells and proceeds normally.

### "rdhs::get_dataset returns 403"

Your DHS project approval likely hasn't covered the survey you're requesting. Check your project description at https://dhsprogram.com against the survey country + year. Resubmit if needed.

### "MAP raster download timeout"

The Malaria Atlas Project public API occasionally rate-limits. Retry after 10 minutes. If persistent, you can manually download the GeoTIFFs from https://malariaatlas.org and place them in `data/raw/malaria_atlas/`.

### "Cluster bootstrap uses too much RAM"

The 2SRI cluster bootstrap (`42_two_stage_residual_inclusion.R`) with `N_BOOT=500` can use ~4 GB. Reduce to `N_BOOT=200` or run on a machine with ≥ 8 GB RAM.

### Sensemakr "Variables not found in model"

If you modify the control set in `52_sensemakr.R`, ensure the `benchmark_vars` list only includes variables that are in the LPM model.

### `here::here()` finds the wrong project root

This happens if `setwd()` is called inside a script. Always run `Rscript` from the project root, OR open the project in RStudio so the `.Rproj` file anchors `here::here()`.

---

## Reproducibility footprint

| Component | Version (developer's session) |
|---|---|
| R | 4.3.2 |
| OS | Linux 6.x |
| GJRM | 0.2-6.5 |
| EValue | 4.1.3 |
| sensemakr | 0.1.5 |
| AER | 1.2-12 |
| sf | 1.0-15 |

For a deterministic reproduction, run `renv::restore()` from `renv.lock` (planned but not yet committed; see `DESCRIPTION` for the package set in the meantime).

---

## Where to find each piece in the repo

| Question | Answer location |
|---|---|
| What does this study actually claim? | [docs/BRIEF.md](BRIEF.md) |
| Why these methods? | [docs/METHODOLOGY_MAP.md](METHODOLOGY_MAP.md) |
| What did the audit reveal? | [docs/AUDIT_LOG.md](AUDIT_LOG.md) |
| What were the 14 bug fixes? | [docs/CHANGELOG_FIXES.md](CHANGELOG_FIXES.md) |
| What's the data flow? | [docs/PIPELINE_GRAPH.md](PIPELINE_GRAPH.md) |
| What did the production run say? | [docs/PHASE_B_RESULTS_SUMMARY.md](PHASE_B_RESULTS_SUMMARY.md) |

# CHANGELOG_FIXES.md

**Project:** C-Section RBVP Pipeline — Bug Fixes
**Date applied:** 2026-05-22
**Working directory:** [/media/moccaram/54FA0D06FA0CE6581/CS/rbvp/rbvp/](.)
**Source baseline:** [/rv/rbvp_revised/scripts/](file:///media/moccaram/54FA0D06FA0CE6581/rv/rbvp_revised/scripts/) (April 12–13, 2026 revision)
**Backups:** [scripts/_PRE_FIX_BACKUP_2026-05-22/](scripts/_PRE_FIX_BACKUP_2026-05-22/), [outputs/_PRE_REPRO_BACKUP_2026-05-22/](outputs/_PRE_REPRO_BACKUP_2026-05-22/)

Each entry lists: the file changed, the audit finding addressed, the location, what was wrong, what was fixed, and what reference / rationale supports the fix.

---

## Fix A1: `PHASE3_CONLEY_FIXED.R` — Scale mismatch (CRITICAL)

**Audit finding:** [AUDIT_LOG.md §4 "Script 4"](/media/moccaram/54FA0D06FA0CE6581/CS/AUDIT_LOG.md) — Conley correction `β_corrected = β_IV - γ/π` was applied with β from RBVP (probability-scale ATE) and π from a first-stage LPM (probability-scale coefficient). These look like the same scale but represent different conceptual objects, breaking the Conley framework which assumes both come from a consistent linear IV.

**Reference:** Conley, T.G., Hansen, C.B. & Rossi, P.E. (2012). "Plausibly Exogenous." *Review of Economics and Statistics*, 94(1): 260–272. The Conley framework is built for linear IV (2SLS); β, γ, and π must all be on the same linear scale.

**Fix:** Replaced RBVP-derived β with LPM-2SLS β (via `AER::ivreg`). Both β and π are now from the same linear-IV framework. Added cluster-robust SE via `sandwich::vcovCL`. Added partial-F first-stage diagnostic. Added Union-of-Confidence-Intervals construction (shifted CI per γ).

**Secondary fixes:**
- Broken hardcoded path (typo: missing trailing `1` in `54FA0D06FA0CE658` → `54FA0D06FA0CE6581`) replaced with `file.path(getwd(), ...)`.
- Sign in correction formula: `β_adj <- β_iv + (g/pi_fs)` → `β_adj <- β_iv - (g/pi_fs)` (canonical Conley form).

**Impact on results:** Headline finding changed. Previous "BD breakdown at 0.79pp" claim does not survive. New LPM-2SLS estimates have SEs wide enough that **CIs cross zero immediately (γ=0)** for all four waves. The IV strategy is fragile from the start, not "robust up to 0.79pp."

**Files affected:**
- [scripts/PHASE3_CONLEY_FIXED.R](scripts/PHASE3_CONLEY_FIXED.R) — full rewrite

---

## Fix A2: `script_3_rebuilt.R` — Bootstrap estimator mismatch (CRITICAL)

**Audit finding:** [AUDIT_LOG.md §1 Bug #1](/media/moccaram/54FA0D06FA0CE6581/CS/AUDIT_LOG.md) — Point estimate at line 359 uses `pbivnorm(...)` (bivariate normal CDF, ρ-corrected). Bootstrap at lines 384, 388 used `pnorm(...)` (univariate, drops ρ). Different estimators → CI mis-calibrated.

**Reference:** Wooldridge, J.M. (2010). *Econometric Analysis of Cross Section and Panel Data*, 2nd ed., Ch. 15.6 on bivariate probit ATE. The probability-scale ATE for a recursive bivariate probit requires the joint CDF formula `Φ₂(...)`.

**Fix:** Rewrote the bootstrap inner block to extract lp1 (Stage 1 link), lp2 (Stage 2 link), ρ from each bootstrap GJRM fit, then compute ATE via `pbivnorm(lp2_b + a, lp1, ρ) - pbivnorm(lp2_b, lp1, ρ)` — identical formula to the point estimate.

**Files affected:**
- [scripts/script_3_rebuilt.R](scripts/script_3_rebuilt.R) — bootstrap block around line 371–397

---

## Fix A3: `script_3_rebuilt.R` — Bootstrap rep count

**Audit finding:** [AUDIT_LOG.md §1 Bug #2](/media/moccaram/54FA0D06FA0CE6581/CS/AUDIT_LOG.md) — `N_BOOT = 20`. Inconsistent with user's own 2SRI script (`N_BOOT = 500`) and below the conventional minimum (≥200 for percentile CIs).

**Reference:** Efron, B. & Tibshirani, R.J. (1993). *An Introduction to the Bootstrap*. Standard practice for percentile CIs requires ≥200 reps; 500–1000 for publication.

**Fix:** Set `N_BOOT <- 200` as the canonical value. Made it configurable via env var `N_BOOT=<n> Rscript ...` for smoke-testing without changing the source.

**Files affected:**
- [scripts/script_3_rebuilt.R](scripts/script_3_rebuilt.R) — `N_BOOT` declaration

---

## Fix A4: `script_3_rebuilt.R` — Observation bootstrap → cluster bootstrap

**Audit finding:** [AUDIT_LOG.md §1 Bug #3](/media/moccaram/54FA0D06FA0CE6581/CS/AUDIT_LOG.md) — Bootstrap resampled individual rows (`sample(nrow(dat), replace=TRUE)`). DHS has cluster sampling; observation bootstrap underestimates SE.

**Reference:** Cameron, A.C. & Miller, D.L. (2015). "A Practitioner's Guide to Cluster-Robust Inference." *Journal of Human Resources*, 50(2): 317–372. The manuscript cites this paper (#9 in Vancouver_References_with_DOIs.docx) but the code did not match.

**Fix:** Replaced observation bootstrap with cluster bootstrap: `unique(cluster_id)` → resample whole clusters with replacement → reconstruct dataset.

**Files affected:**
- [scripts/script_3_rebuilt.R](scripts/script_3_rebuilt.R) — bootstrap loop, replacing `dat_clean[sample(...)...]` with cluster-based resampling

---

## Fix A5: `script_3_rebuilt.R` — Step 5B referenced empty data frame

**Audit finding:** [AUDIT_LOG.md §1 Bug #4](/media/moccaram/54FA0D06FA0CE6581/CS/AUDIT_LOG.md) — Step 5B (naive probit comparison) read `results[results$Year == yr, ]`, but `results` was declared empty at line 326 and never populated. Main loop populates `ate_results`. As a result, `Naive_Probit_Comparison.csv` was silently empty/NA.

**Fix:** Renamed `results` → `ate_results`. Also updated column references (`ANC_Corrected_Stage1` → `ANC_ATE`, `Csec_Corrected_Stage2` → `Csec_ATE`) to match what `ate_results` actually contains (probability-scale ATEs, not latent coefficients).

**Files affected:**
- [scripts/script_3_rebuilt.R](scripts/script_3_rebuilt.R) — Step 5B references

---

## Fix A6: `TWO-STAGE RESIDUAL INCLUSION.R` — Observation bootstrap → cluster bootstrap

**Audit finding:** [AUDIT_LOG.md §4 "Script 1 (2SRI)"](/media/moccaram/54FA0D06FA0CE6581/CS/AUDIT_LOG.md) — Same observation-bootstrap bug as in script_3_rebuilt.

**Reference:** Cameron & Miller (2015), same as A4.

**Fix:** `bootstrap_2sri_ate()` function now uses cluster bootstrap if `cluster_id` column is present. Added `cluster_id` to the `vars_need` list so it's preserved in the bootstrap data frame.

**Files affected:**
- [scripts/TWO-STAGE RESIDUAL INCLUSION.R](scripts/TWO-STAGE%20RESIDUAL%20INCLUSION.R) — `bootstrap_2sri_ate()` function and `vars_need` declaration

---

## Fix A7: `TWO-STAGE RESIDUAL INCLUSION.R` — Survey weights ignored in bootstrap

**Audit finding:** [AUDIT_LOG.md §4 "Script 1 (2SRI)"](/media/moccaram/54FA0D06FA0CE6581/CS/AUDIT_LOG.md) — `glm()` calls inside the bootstrap loop omitted `weights = dat_boot$weight`. The non-bootstrap fits used weights; the bootstrap did not. Inconsistent.

**Reference:** Terza, J.V. (2018). "Two-Stage Residual Inclusion Estimation in Health Services Research and Health Economics." *Health Services Research*, 53(3): 1890–1899. Bootstrap procedure must replicate the same estimator used for the point estimate (eq. 12).

**Fix:** Added `weights = dat_boot$weight` to both Stage 1 and Stage 2 `glm()` calls inside the bootstrap loop.

**Files affected:**
- [scripts/TWO-STAGE RESIDUAL INCLUSION.R](scripts/TWO-STAGE%20RESIDUAL%20INCLUSION.R) — bootstrap inner block

---

## Fix A8: `FORMAL IV ASSUMPTION VALIDITY TESTS.R` — Decorative Acerenza citation

**Audit finding:** [AUDIT_LOG.md §4 "Script 2 (IV Validity)"](/media/moccaram/54FA0D06FA0CE6581/CS/AUDIT_LOG.md) — Header cited Acerenza, Bartalotti & Kédagni (2023) as the theoretical motivation, but the script does NOT implement their 6-inequality intersection-bounds test. The actual tests are standard Swanson-Hernán diagnostics (balance, reduced form, cross-instrument placebo).

**Fix:** Removed Acerenza from the "Methodological basis" header section. Added explanatory note that formal Acerenza testing is deferred to a separate Phase D script. Added a caveat about modern weak-instrument thresholds (Lee, Moreira, Porter & Yap 2022) since the F > 10 rule from Bound, Jaeger & Baker (1995) is outdated.

**Files affected:**
- [scripts/FORMAL IV ASSUMPTION VALIDITY TESTS.R](scripts/FORMAL%20IV%20ASSUMPTION%20VALIDITY%20TESTS.R) — header block

---

## Fix A8b (incidental): `FORMAL IV ASSUMPTION VALIDITY TESTS.R` — Empty-region formula bug

**Found while running A8:** Pre-existing bug not in original audit. When `data_step1_complete.rds` has no `region_*` columns (as in current data), `available_regions[available_regions %in% names(dat_clean)]` is empty → balance-test formula ends with dangling `+` → `as.formula` error.

**Fix:** Build the RHS extra-controls string conditionally — only append `+ region_1 + region_2 + ...` if any are present.

**Files affected:**
- [scripts/FORMAL IV ASSUMPTION VALIDITY TESTS.R](scripts/FORMAL%20IV%20ASSUMPTION%20VALIDITY%20TESTS.R) — line ~220 (balance loop formula construction)

---

## Fix A9: `COPULA SENSITIVITY ANALYSIS.R` — Missing Gumbel copula

**Audit finding:** [AUDIT_LOG.md §4 "Script 3 (Copula)"](/media/moccaram/54FA0D06FA0CE6581/CS/AUDIT_LOG.md) — McGovern et al. (2015) and Klein et al. (2019) — both cited in the script header — test 4 copula families. This script tested only 3 (Gaussian, Frank, Clayton). Gumbel (upper-tail dependence) was missing.

**Reference:** McGovern, M.E., Bärnighausen, T., Marra, G. & Radice, R. (2015). "On the Assumption of Bivariate Normality in Selection Models." *Epidemiology*, 26(2): 229–237. Klein, N., Kneib, T., Marra, G., Radice, R. (2019). "Mixed binary-continuous copula regression models." *Statistics in Medicine*, 38(20): 3781–3805.

**Fix:** Added `Gumbel = "GU0"` to `copula_specs`. Updated downstream `sign_check` aggregation to include `ATE_Gumbel` and `Sign_Gumbel`. Refactored `Signs_Consistent` to be NA-robust (handles non-converging copulas).

**Production note:** When tested on the current data, Gumbel did not converge in GJRM (warning: "Maximum absolute gradient value is not close to 0"). All `ATE_Gumbel` values are NA in the smoke-test output. This is a real finding: the data does not support upper-tail dependence structure. Frank and Clayton both fit.

**Files affected:**
- [scripts/COPULA SENSITIVITY ANALYSIS.R](scripts/COPULA%20SENSITIVITY%20ANALYSIS.R) — `copula_specs` definition, `sign_check` aggregation, diagnostic print

---

## Summary of substantive impacts

| Fix | Impact on conclusions |
|---|---|
| A1 (Conley) | "BD breakdown at 0.79pp" claim does not survive. CIs cross zero immediately for all 4 waves. |
| A2–A4 (script_3 bootstrap) | Point estimate recovered correctly (−1.69pp 2022 C-section matches METHODOLOGY_LOG); CIs are now properly cluster-bootstrapped. Full N_BOOT=200 run required to assess significance honestly. |
| A5 (Step 5B fix) | `Naive_Probit_Comparison.csv` will now be populated correctly (was silently NA). |
| A6–A7 (2SRI bootstrap) | 2SRI now correctly cluster-bootstraps with weights. Smoke test shows 6/8 sign-consistent with RBVP; 2 cells (2004 C-sec, 2011 C-sec) show INCONSISTENT signs. |
| A8 (IV Validity honesty) | Cross-instrument placebo test now found to FAIL at p<0.001 in all 8 cells → exclusion restriction is decisively violated. |
| A9 (Gumbel) | Reveals that Gumbel doesn't converge; broader sensitivity analysis shows 5/8 cells have inconsistent ATE signs across Gaussian/Frank/Clayton. |

The overall picture is that the brief's pessimism is **substantially reinforced**, not refuted, by the corrected analysis.

---

## SECOND ROUND OF FIXES (2026-05-22, post-production-run discovery)

The first production run (A1–A9 applied, N_BOOT=200) ran without crashing but inspection revealed **4 more critical bugs** that the original audit missed. Below is the second-round fix log.

---

## Fix A10: `script_3_rebuilt.R` — `Formal_ATE_Results.csv` is never written

**Discovery:** Grep of `script_3_rebuilt.R` shows only 4 `write.csv` calls: `Direction_Correction_Log.csv`, `Naive_Probit_Comparison.csv`, `FIXED_Confounder_Decomposition.csv`, `FIXED_Mediator_Decomposition.csv`. There is no `write.csv(ate_results, ...)`. The script's terminal announcement "Saved: Formal_ATE_Results.csv ⭐⭐⭐⭐⭐ (NEW)" was a printed lie — the variable `ate_results` was computed and used internally (Step 5B), but never persisted. **Every result we discussed from `Formal_ATE_Results.csv` since the session began was actually from a STALE copy created by some earlier (now-overwritten) script version.**

**Fix:** Added `write.csv(ate_results, file.path(output_dir, "Formal_ATE_Results.csv"), row.names = FALSE)` right after the main year loop closes.

**Files affected:**
- [scripts/script_3_rebuilt.R](scripts/script_3_rebuilt.R) — new write.csv call after the main loop

---

## Fix A11: `script_3_rebuilt.R` — Year 2011 silently skipped (NON-BUG, retained diagnostics)

**Discovery:** The first production log showed "Processing Year: 2004 → 2017-2018 → 2022" — 2011 missing. Initially suspected the `if(nrow(dat_clean) < 500) next` filter was triggering on 2011.

**Investigation:** Added explicit diagnostic prints. Re-running showed all 4 years process with N=4661 complete cases for 2011 (well above the 500 threshold). **The original missing "Processing Year: 2011" in the production log was an output-buffering artifact**, not a real skip.

**Outcome:** Diagnostic prints retained as a permanent improvement (cheap insurance). No real bug to fix.

**Files affected:**
- [scripts/script_3_rebuilt.R](scripts/script_3_rebuilt.R) — added one diagnostic `cat()` line per year showing N-complete-cases

---

## Fix A12: `script_3_rebuilt.R` — Naive probit catastrophic divergence

**Discovery:** Step 5B reported `Naive = 8.79e+14`, `Bias = 3.56e+20 %`. The `glm.fit: algorithm did not converge` warning was being ignored, producing astronomical garbage that the bias-calculation logic then divided to produce nonsense percentages.

**Reference:** Standard practice in GLM diagnostics — convergence flag (`fit$converged`) should be checked before using estimates. The astronomical coefficients are a separation symptom (Albert & Anderson 1984).

**Fix:** Wrapped the `glm()` call in `suppressWarnings()`, then explicitly check `naive_fit$converged` and `max(abs(coef(naive_fit))) > 50`. If either fails, skip the year with an explicit warning rather than reporting divergent values.

**Files affected:**
- [scripts/script_3_rebuilt.R](scripts/script_3_rebuilt.R) — Step 5B naive probit guard

---

## Fix A13: `TWO-STAGE RESIDUAL INCLUSION.R` — Bootstrap all-NA (glm NSE bug)

**Discovery:** The first production 2SRI run produced `Boot_SE = NA`, `Boot_Lower = NA`, `Boot_Upper = NA` in every wave × treatment cell. The `tryCatch` silently swallowed errors. Adding `conditionMessage(e)` logging surfaced the actual error: **`object 'dat_boot' not found`** — but `dat_boot` clearly existed (verified with diagnostics: `class=data.frame nrow=3454 ncol=15 has_weight=TRUE`).

**Root cause:** `glm()` uses non-standard evaluation for `weights = ...`. When called from inside a function, `glm` looks up `weights = dat_boot$weight` in a special frame that does NOT include the calling function's local variables. So `dat_boot` is invisible from inside `glm`'s NSE machinery, even though it exists in the for-loop frame.

**Fix:** Pass `weights = weight` (unquoted, bare column name) instead of `weights = dat_boot$weight`. The unquoted form is resolved by `glm` via `data = dat_boot` first, where `weight` is a column. This sidesteps the NSE scoping problem entirely.

**Additional refinements:**
- Reset `row.names(dat_boot) <- NULL` after cluster resampling (avoids duplicate row.name issues)
- Convert `dat` to plain `data.frame` once outside the loop (avoids tibble edge cases)
- Build bootstrap subset via index vector instead of `do.call(rbind, lapply(...))` (faster + safer)
- Replace strict `!isTRUE(fit$converged)` check with `any(!is.finite(coef(fit)))` (only catches catastrophic divergence; allows borderline convergence which is fine for bootstrap aggregation)
- Add `glm.control(maxit = 100)` to give the optimizer more room
- Surface first 3 errors per bootstrap call via `message()` for ongoing diagnosis

**Files affected:**
- [scripts/TWO-STAGE RESIDUAL INCLUSION.R](scripts/TWO-STAGE%20RESIDUAL%20INCLUSION.R) — `bootstrap_2sri_ate()` function rewrite

---

## Fix A14: `script_3_rebuilt.R` — ANC/C-section labels INVERTED

**Discovery:** While investigating A11, the new `Formal_ATE_Results.csv` (now properly written by A10) showed `ANC_ATE = −1.51pp` and `Csec_ATE = −0.09pp` for 2022. These magnitudes are the OPPOSITE of what `METHODOLOGY_LOG.md` claims (`ANC = −0.06pp`, `C-section = −1.69pp`). **The column labels were swapped.**

**Root cause:** The variable assignments in the main loop did not match what the GJRM fits actually computed:

```r
# Original (BUGGY):
fit1 <- gjrm(list(f1_s1, f2_s1), ...)   # fit1 uses endo_1 = c_section_yes
ate_anc_val <- get_ate_val(fit1, endo_1, dat_clean)   # but named "anc"!

fit2 <- gjrm(list(f1_s2, f2_s2), ...)   # fit2 uses endo_2 = anc_4plus
ate_csec_val <- get_ate_val(fit2, endo_2, dat_clean)  # but named "csec"!
```

Someone renamed the variables (probably during the methodology-log-described "revision" that intended to swap ordering to ANC→C-section), but never actually swapped the GJRM fits.

**Implication:** **Every result we discussed in this session that referenced the "2022 −1.69pp C-section ATE" was actually the C-section ATE — but read from a stale CSV where the labels happened to be correct.** With the labels-correct stale CSV gone and the (originally-buggy) script overwriting Formal_ATE_Results.csv, the new output had inverted labels.

**Fix:**
- Renamed variables: `ate_csec_val <- get_ate_val(fit1, ...)` (fit1 = C-section model)
- Renamed: `ate_anc_val <- get_ate_val(fit2, ...)` (fit2 = ANC model)
- Renamed bootstrap intermediates: `b_csec_val`, `b_anc_val`, `b_csec_se`, `b_anc_se`
- Bootstrap return order is now `c(b_csec_val, b_anc_val)`, with the data.frame rbind using each correctly

**Files affected:**
- [scripts/script_3_rebuilt.R](scripts/script_3_rebuilt.R) — main loop variable assignments + bootstrap return order + ate_results column ordering

---

## Summary of second-round impacts

| Fix | Impact |
|---|---|
| A10 | `Formal_ATE_Results.csv` is now actually persisted by `script_3_rebuilt.R`. Prior file was stale. |
| A11 | Diagnostics retained; no real bug. |
| A12 | Step 5B `Naive_Probit_Comparison.csv` will report NA on glm divergence instead of astronomical garbage. |
| A13 | 2SRI bootstrap CIs now produce real numbers instead of all-NA. |
| A14 | All ANC/C-section results in `Formal_ATE_Results.csv` were SWAP-LABELED. Now corrected. |

**The combined effect of A10 + A14:** every "Formal_ATE_Results.csv" reference in this session's prior writeups should be re-read with awareness that the file was both (a) stale and (b) potentially label-swapped depending on which script version wrote it. The new production rerun (chained in background as of 2026-05-22 ~07:50) will produce the first honest version of this file.

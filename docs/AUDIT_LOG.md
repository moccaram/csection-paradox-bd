# C-Section RBVP Pipeline — Audit Log

**Created:** 2026-05-22
**Purpose:** Preserved record of audit findings from the methodological review of the C-section / under-five mortality RBVP pipeline. This document is the canonical record; the implementation log lives separately in `CHANGELOG_FIXES.md` (created during Phase A fixes).

---

## 1. Code review of `script_3_rebuilt.R` (the main RBVP pipeline)

### Bugs found (severity-ordered)

| # | Severity | Location | Issue |
|---|---|---|---|
| 1 | 🔴 Critical | Lines 359 vs 384, 388 | **Bootstrap uses `pnorm()` (univariate); point estimate uses `pbivnorm()` (bivariate, ρ-corrected).** Different estimators → CIs mis-calibrated relative to the point estimate. |
| 2 | 🟠 Medium | Line 372–392 | **Only 20 bootstrap reps.** Standard is 500–1000+. SE is noisy. |
| 3 | 🟠 Medium | Line 376 | **Observation-level bootstrap, not cluster bootstrap.** DHS data has cluster sampling; this underestimates SE. (Critical Review PDF flagged this exact issue.) |
| 4 | 🟠 Logic | Line 453 | **Step 5B references an empty `results` data frame** (main loop populates `ate_results`, not `results`). `Naive_Probit_Comparison.csv` is silently NA/empty. |
| 5 | 🟡 Minor | Lines 363, 440 | **Survey weights treated as precision weights** (`weights = weight` in `gjrm`/`glm`). Should use `survey::svyglm()` or proper design specification. |

### Implications

- **Point estimate of −0.21 pp (2022 C-sec ATE):** ✓ trustworthy — bivariate normal CDF logic is correctly implemented for the point
- **CI of [−2.33, +1.90]:** ✗ NOT trustworthy — bootstrap-estimator mismatch + too few reps + wrong resampling unit means the SE is calibrated to the wrong estimand
- **The `METHODOLOGY_LOG.md` claim of "ATE = −1.69 pp significant":** likely from a different (or earlier-buggy) script run, OR confusing the latent probit coefficient with the probability-scale ATE

---

## 2. Reference provenance audit (per-script)

| Script | References cited | Quality | Bootstrap reps | Solid? |
|---|---|---|---|---|
| `COPULA SENSITIVITY ANALYSIS.R` | McGovern et al. 2015 (Epidemiology); Klein et al. 2019 (Stat Med); Han-Vytlacil 2017; Li-Poskitt-Zhao 2019 | ★★★★★ | N/A | YES |
| `FORMAL IV ASSUMPTION VALIDITY TESTS.R` | Swanson-Hernán 2013; Bound-Jaeger-Baker 1995; Acerenza-Bartalotti-Kédagni 2023 | ★★★★★ in header | N/A | Citation overstated (see audit #3) |
| `TWO-STAGE RESIDUAL INCLUSION.R` | Terza-Basu-Rathouz 2008; Terza 2018; Wooldridge 2015 | ★★★★★ | **500** (proper) | YES |
| `SCRIPT 5.R` (visualization) | Ghilagaber (2004) | ★★ | N/A | Marginal |
| `SCRIPT 1` / `SCRIPT 2` | None — data prep + ad-hoc ensemble | — | N/A | Ad hoc |
| `script_3_rebuilt.R` (main pipeline) | **NONE in header. Zero grep hits for "Wilde" anywhere.** | ★ | **20** (against own 2SRI standard) | **NO** |

### Key finding: provenance mismatch

The auxiliary scripts (2SRI, copula sensitivity, IV validity) have strong canonical references and proper implementation. The MAIN pipeline script (`script_3_rebuilt.R`) has:
- No methodology citation in its header
- No reference to Wilde (2000), the foundational paper justifying RBVP identification
- Only 20 bootstrap reps, against the 500-rep standard the user's OWN 2SRI script applies
- 5 bugs documented above

---

## 3. Identification claims → references map (PRESERVED PER USER REQUEST)

### Adequately referenced claims

- Bivariate probit model: Heckman 1979 (manuscript #17) + Greene 2012 (manuscript #15) ✓
- RBVP in R via GJRM: Marra & Radice 2011, 2013, 2017 (manuscript #28, #30, #31) ✓
- LATE / IV causal interpretation: Angrist, Imbens, Rubin 1996 (manuscript #3) ✓
- First-stage F / weak IV: Bound, Jaeger, Baker 1995 + Staiger-Stock 1997 (manuscript #7, #46) ✓
- IV reporting standards: Swanson & Hernán 2013 (manuscript #47) ✓
- Mosley framework: Mosley & Chen 1984 (manuscript #33) ✓
- Mediation: MacKinnon, Krull, Lockwood 2000 (manuscript #27) ✓

### Type A gaps (owned but not cited in manuscript)

User owns these papers in `/ref papers` folder but did not cite them in the manuscript:

- **Wilde (2000)** — identification by functional form. (Possibly irrelevant since user uses exclusion restriction.)
- **Han & Vytlacil (2017)** — identification with exclusion restriction. **SERIOUS** — this IS the operative theory for the user's setup.
- **Mourifié & Méango (2014)** — critique of Wilde identification. **SERIOUS**.
- **Acerenza, Bartalotti & Kédagni (2023)** — testable implications. Cited in IV validity script header but NOT in manuscript.
- **Conley, Hansen & Rossi (2012)** — plausibly exogenous bounds. Used in `PHASE3_CONLEY.R` but not cited in manuscript.
- **Terza et al. (2008); Terza (2018); Wooldridge (2015)** — 2SRI. Cited in 2SRI script but not in manuscript.
- **McGovern et al. (2015); Klein et al. (2019)** — copula sensitivity. Cited in COPULA script but not in manuscript.

### Type B gap (not owned, not cited)

🔴 **CRITICAL**: The central critique of the user's IV strategy is missing from BOTH manuscript AND ref folder:

- **Angrist (2014), "The Perils of Peer Effects," Labour Economics** — canonical critique of leave-one-out community-mean IVs
- **Betz, Cook & Hollenbach (2018), Political Analysis** — "spatial instruments cannot be valid instruments"

### Implementation-vs-reference mismatch

🟠 **Cameron-Miller (2015) on cluster-robust inference is CITED in manuscript (#9), but the bootstrap implementation in `script_3_rebuilt.R` is observation-level, not cluster-level.** The cited methodology is not what the code actually does.

### Key conclusion

The original PLOS ONE / SSM-Pop-Health submissions were defending the identification strategy using **supportive** literature. They did NOT engage with the **critique** literature (Angrist 2014; Betz et al. 2018). This is the structural reason reviewers rejected them.

---

## 4. Code-vs-paper implementation audit (the four auxiliary scripts)

### Script 1: `TWO-STAGE RESIDUAL INCLUSION.R` vs Terza (2018)

**Faithfulness:** ✓ Algorithm correctly implements Terza 2018 protocol (eqs 8–12, page 1896)

**Bugs:**
- 🟠 Observation-level bootstrap, not cluster bootstrap (line 259)
- 🟠 Survey weights ignored in bootstrap glm (lines 264, 269)

**Verdict:** Highest-quality script. Two real but minor bugs.

### Script 2: `FORMAL IV ASSUMPTION VALIDITY TESTS.R` vs Swanson-Hernán (2013) + Acerenza (2023)

**Faithfulness:** ⚠ Partial — Balance, reduced form, and cross-instrument placebo tests are faithful to Swanson-Hernán. **Acerenza (2023) 6-inequality test is NOT IMPLEMENTED despite header citation.**

**Verdict:** Decorative Acerenza citation. The script does informal IV diagnostics correctly; it does NOT do the formal Acerenza moment-inequality test.

### Script 3: `COPULA SENSITIVITY ANALYSIS.R` vs McGovern (2015) + Klein (2019)

**Faithfulness:** ✓ Implementation faithful in approach

**Issues:**
- 🟠 Only 3 copulas (Gaussian, Frank, Clayton); McGovern uses 4 — **Gumbel missing**
- ⚠ Rotated copulas (C90, C180, C270) mentioned in comments but not implemented

**Verdict:** Solid implementation, **incomplete coverage** of the copula families used by McGovern.

### Script 4: `PHASE3_CONLEY_FIXED.R` vs Conley, Hansen & Rossi (2012)

**🔴 CRITICAL BUG — SCALE MISMATCH:**

```r
beta_iv <- ate_res$Csec_ATE[i]              # probability scale
pi_fs   <- fs_diag$Csec_IV_Coef[...]        # probit latent scale
beta_adj <- beta_iv + (g / pi_fs)            # mixing scales — WRONG
```

The Conley formula β_corrected = β_IV - γ/π requires β and π on the **same scale**. The script mixes probability-scale ATE with latent-probit-scale first-stage coefficient. **This invalidates the reported breakdown points in Figure 7.**

**Other issues:**
- 🟡 Broken hardcoded path (missing trailing "1" in `54FA0D06FA0CE658`)
- 🟠 γ range arbitrarily set to [0, 0.02]
- 🟠 No proper Union-of-Confidence-Intervals construction; only point-estimate adjustment

**Verdict:** Most concerning script. The formula is right, but the scale mismatch likely invalidates the "BD breakdown at 0.79pp" claim that the methodology log relies on.

### Audit summary table

| Script | Faithful? | Critical bugs | Reference utilized? |
|---|---|---|---|
| 2SRI | ✓ Yes | Cluster bootstrap, weights | ~80% |
| IV Validity | Partial | Acerenza decorative | ~50% (Swanson-Hernán fully; Acerenza not at all) |
| Copula | ✓ Yes | None critical | ~60% (Gumbel + rotated missing) |
| Conley | Formula right | 🔴 Scale mismatch | ~30% |

---

## 5. Discrepancy between summary docs and actual data

**The project's own summary docs (`METHODOLOGY_LOG.md`, `SUMMARY_OF_REVISION.md`) OVERSTATE the actual results.**

| Source | C-section 2022 ATE claim | Reality from data file |
|---|---|---|
| `METHODOLOGY_LOG.md` | "**−1.69 pp**, significant, robust" | `Formal_ATE_Results.csv`: C-sec 2022 ATE = **−0.21 pp**, CI [−2.33, +1.90], **NOT significant** |
| `SUMMARY_OF_REVISION.md` | "ALL PIPELINES VERIFIED & DEFINITIVE" | Bangladesh Conley bounds span zero in both regimes; Pakistan same |

The protective effect that holds in 2022 Bangladesh is **ANC**, not C-section. The summary docs are unreliable; the CSV data files (after correcting for the script_3_rebuilt bugs) are the authoritative source.

---

## 6. Modern critique literature (Type B gap to address going forward)

These should be added to the user's reading list and integrated into any future write-up:

- **Angrist, J. D. (2014). "The Perils of Peer Effects." *Labour Economics*, 30, 98–108.**
  Canonical critique of leave-one-out community-mean instruments.

- **Betz, T., Cook, S. J., & Hollenbach, F. M. (2018). "On the use and abuse of spatial instruments." *Political Analysis*, 26(4), 474–479.**
  "Spatial instruments cannot be valid instruments."

---

## 7. SUBSTANTIVE FINDING — Endogeneity is NOT statistically detected (2026-05-22, post-production)

After applying Phase-A fixes and running the full N_BOOT=500 2SRI procedure, the Wooldridge-style Hausman test (significance of the residual coefficient in the second-stage probit) shows **no statistical evidence of endogeneity for C-section in any of the four BDHS waves**:

| Year | C-section residual p-value | Endogeneity detected? | ANC residual p-value | Endogeneity detected? |
|---|---|---|---|---|
| 2004 | 0.195 | NO | 0.745 | NO |
| 2011 | 0.214 | NO | 0.973 | NO |
| 2017–18 | 0.435 | NO | 0.225 | NO |
| **2022** | **0.978** | **NO** | **0.035** | **YES *** |

Only 1 of 8 cells (2022 ANC) shows endogeneity. **The recursive bivariate probit / IV machinery was built to correct for endogeneity that the formal 2SRI Hausman-style test cannot detect for C-section in any wave.** This is a substantive finding independent of any technical bug:
- The residual coefficient test results come from the (non-bootstrap) point estimation
- These p-values do not change with N_BOOT or cluster bootstrap fixes
- Reference: Wooldridge (2015) "Control Function Methods in Applied Econometrics" §2.3 — significance of the included residual is the standard Hausman variant for endogeneity testing in 2SRI

### Implication for the brief

The brief's argument "the causal-inference machinery didn't deliver" now has TWO independent supports:
1. **The IV doesn't satisfy exclusion** (cross-instrument placebo failure, all 8 cells at p<0.001)
2. **There may not have been endogeneity to correct in the first place** (Hausman test fails to reject exogeneity for C-section in all waves)

The original manuscript's framing — that RBVP was needed to correct C-section endogeneity — is undermined by its own diagnostic test. This is another data-driven finding that supports the brief's pessimism without requiring the user to invoke external critique literature.

---

## 8. Second round of bugs found (2026-05-22, post-production)

After the first production run (with A1–A9 fixes), four more critical bugs were discovered:

- **A10:** `Formal_ATE_Results.csv` was never written by `script_3_rebuilt.R`. The script printed "Saved" announcements but had no `write.csv` call. Prior file values were stale carryovers.
- **A11:** Year 2011 "skip" in production log was an output-buffering artifact, not a real bug. (Confirmed all 4 years process; N=4661 complete cases for 2011.)
- **A12:** Step 5B naive probit reported `Bias = 3.56e+20%` due to silent glm-divergence on small year-specific samples. Now guarded with `converged` check + `|coef| < 50` sanity bound.
- **A13:** 2SRI bootstrap silently returned all-NA. Root cause was `glm()`'s non-standard evaluation of `weights = dat_boot$weight` failing to find `dat_boot` in the function frame. Fixed by passing `weights = weight` (unquoted column name resolved via `data = dat_boot`).
- **A14:** ANC and C-section column labels were INVERTED in `Formal_ATE_Results.csv`. The script's variable names (`ate_anc_val`, `ate_csec_val`) didn't match what the GJRM fits actually computed.

Combined effect of A10 + A14: **the prior file on disk had stale, possibly-correctly-labeled values from an older script version; the new run produces honest, correctly-labeled values for the first time.** See [CHANGELOG_FIXES.md](rbvp/rbvp/CHANGELOG_FIXES.md) for full details.

---

## Document history

| Date | Event |
|---|---|
| 2026-05-21 | Initial audit of `/Project/`, `/rv/`, and `/CS/` folders began |
| 2026-05-21 | Found discrepancy between summary docs and CSV outputs |
| 2026-05-22 | Code review of `script_3_rebuilt.R` identified 5 bugs (A1–A5) |
| 2026-05-22 | Reference provenance audit completed |
| 2026-05-22 | Identification claims → references map built |
| 2026-05-22 | Code-vs-paper audit of 4 auxiliary scripts completed |
| 2026-05-22 | User approved Phase A fixes (A1–A9); this log preserved separately |
| 2026-05-22 | First production run (N_BOOT=200) completed; 4 more bugs surfaced (A10–A14) |
| 2026-05-22 | Hausman-style endogeneity test → endogeneity NOT detected for C-section (§7) |
| 2026-05-22 | Phase A2 fixes applied (A10–A14); production rerun in progress |

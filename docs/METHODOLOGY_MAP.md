# METHODOLOGY_MAP.md

**Project:** C-Section RBVP Pipeline — Output × Reference Map
**Updated:** 2026-05-22

For each script output, this file lists the methodological references that authorize the procedure, with page/section pointers. Closes the Type A provenance gaps identified in [AUDIT_LOG.md §3](/media/moccaram/54FA0D06FA0CE6581/CS/AUDIT_LOG.md).

---

## `Formal_ATE_Results.csv` — Main RBVP ATEs

| Procedure | Reference | Pointer |
|---|---|---|
| Recursive bivariate probit identification | Heckman, J.J. (1978). "Dummy Endogenous Variables in a Simultaneous Equation System." *Econometrica*, 46(4): 931–959. | Equations 1.1–1.3 |
| Bivariate probit estimation (theory) | Maddala, G.S. (1983). *Limited-Dependent and Qualitative Variables in Econometrics*. Cambridge University Press. | Chapter 8 |
| Modern bivariate probit (textbook) | Greene, W.H. (2012). *Econometric Analysis*, 7th ed. Pearson. | Chapter 17.5 |
| GJRM package (R implementation) | Marra, G. & Radice, R. (2011). "Estimation of a semiparametric recursive bivariate probit model in the presence of endogeneity." *Canadian Journal of Statistics*, 39(2): 259–279. | Full paper |
| Identification with exclusion restriction | Han, S. & Vytlacil, E.J. (2017). "Identification in a generalization of bivariate probit models with dummy endogenous regressors." *Journal of Econometrics*, 199(1): 63–73. | Theorem 1 |
| Probability-scale ATE formula (Φ₂) | Greene (2012) Section 17.5.2; coded as `pbivnorm(lp2_b + a, lp1, ρ) - pbivnorm(lp2_b, lp1, ρ)` in `script_3_rebuilt.R` line 359 | — |
| Cluster bootstrap inference | Cameron, A.C. & Miller, D.L. (2015). "A Practitioner's Guide to Cluster-Robust Inference." *Journal of Human Resources*, 50(2): 317–372. | Sections 4–5 |

**Type A gap from audit:** Han & Vytlacil (2017) was in the user's ref folder but not cited in the original manuscript. Closing this gap is documented here.

---

## `2SRI_Full_Results.csv`, `2SRI_Summary_Comparison.csv` — 2SRI Robustness

| Procedure | Reference | Pointer |
|---|---|---|
| 2SRI algorithm | Terza, J.V., Basu, A. & Rathouz, P.J. (2008). "Two-stage residual inclusion estimation: Addressing endogeneity in health econometric modeling." *Journal of Health Economics*, 27(3): 531–543. | Equations 6–9 |
| 2SRI for binary outcomes & treatments | Terza, J.V. (2018). "Two-Stage Residual Inclusion Estimation in Health Services Research and Health Economics." *Health Services Research*, 53(3): 1890–1899. | Eqs (8)–(12), pp. 1896–1898 |
| Control function methods | Wooldridge, J.M. (2015). "Control Function Methods in Applied Econometrics." *Journal of Human Resources*, 50(2): 420–445. | Section 2 |
| Endogeneity test via residual coefficient (robust Hausman) | Wooldridge (2015) Section 2.3 | — |
| Cluster bootstrap | Cameron & Miller (2015), as above | — |

---

## `IV_Balance_Table.csv`, `IV_Reduced_Form.csv`, `IV_Placebo_Tests.csv`, `IV_Validity_Summary.csv` — IV Diagnostics

| Procedure | Reference | Pointer |
|---|---|---|
| IV reporting checklist | Swanson, S.A. & Hernán, M.A. (2013). "Commentary: How to report instrumental variable analyses." *Epidemiology*, 24(3): 370–374. | Box 1 |
| First-stage F threshold | Bound, J., Jaeger, D.A. & Baker, R.M. (1995). "Problems with instrumental variables estimation when the correlation between the instruments and the endogenous explanatory variable is weak." *Journal of the American Statistical Association*, 90(430): 443–450. | F > 10 rule |
| Modern weak-IV thresholds (caveat) | Lee, D.S., McCrary, J., Moreira, M.J. & Porter, J. (2022). "Valid t-ratio Inference for IV." *American Economic Review*, 112(10): 3260–3290. | F > 104.7 for valid t-ratio |
| LATE framework (interpretation) | Angrist, J.D., Imbens, G.W. & Rubin, D.B. (1996). "Identification of causal effects using instrumental variables." *Journal of the American Statistical Association*, 91(434): 444–455. | Theorem 1 |
| **Cross-instrument placebo logic** | Standard practice; consistent with Swanson-Hernán Box 1 item 5 | — |

**Note on the Acerenza citation:** The original script header cited Acerenza, Bartalotti & Kédagni (2023) but did not implement their 6-inequality test. The header has been corrected to acknowledge this (see Fix A8 in [CHANGELOG_FIXES.md](CHANGELOG_FIXES.md)). Formal Acerenza testing is deferred to a separate Phase D script.

---

## `Copula_ATE_Comparison.csv`, `Copula_Rho_Comparison.csv`, `Copula_AIC_Comparison.csv`, `Copula_SignFlip_Check.csv` — Copula Sensitivity

| Procedure | Reference | Pointer |
|---|---|---|
| Copula approach to relaxing normality | McGovern, M.E., Bärnighausen, T., Marra, G. & Radice, R. (2015). "On the Assumption of Bivariate Normality in Selection Models: A Copula Approach Applied to Estimating HIV Prevalence." *Epidemiology*, 26(2): 229–237. | Methods section |
| Copula bivariate probit implementation | Klein, N., Kneib, T., Marra, G. & Radice, R. (2019). "Mixed binary‐continuous copula regression models with application to adverse birth outcomes." *Statistics in Medicine*, 38(20): 3781–3805. | Sections 2–3 |
| Identification across copula families | Han & Vytlacil (2017), as above | — |
| ATE robustness under copula misspecification | Li, C., Poskitt, D.S. & Zhao, X. (2019). "The bivariate probit model, maximum likelihood estimation, pseudo true parameters and partial identification." *Journal of Econometrics*, 209(1): 94–113. | Theorem 4 |

**Copula codes used in GJRM:**
- `Gaussian` → default (bivariate normal)
- `Frank` → `"F"` (symmetric)
- `Clayton` → `"C0"` (lower-tail dependence, positive)
- `Gumbel` → `"GU0"` (upper-tail dependence, positive) — **does not converge on this data** (see Fix A9 production note)

---

## `Conley_IV_Estimates_LPM.csv`, `Conley_Full_Curves.csv`, `Conley_Breakdown_Corrected.csv` — Plausibly Exogenous Bounds

| Procedure | Reference | Pointer |
|---|---|---|
| Plausibly exogenous IV framework | Conley, T.G., Hansen, C.B. & Rossi, P.E. (2012). "Plausibly Exogenous." *Review of Economics and Statistics*, 94(1): 260–272. | Section 2, equations (3)–(5) |
| Union of Confidence Intervals (UCI) approach | Conley, Hansen & Rossi (2012) Section 3.1 | — |
| Linear 2SLS estimator | Wooldridge, J.M. (2010). *Econometric Analysis of Cross Section and Panel Data*, 2nd ed., MIT Press | Chapter 5 |
| Cluster-robust SE | Cameron & Miller (2015) | Section 4 |

**Type A gap from audit:** Conley et al. (2012) was used in `PHASE3_CONLEY_FIXED.R` but not cited in the manuscript. Closing this gap is documented here.

---

## `FIXED_Confounder_Decomposition.csv`, `FIXED_Mediator_Decomposition.csv` — Mediation Analysis

| Procedure | Reference | Pointer |
|---|---|---|
| Mediation decomposition (univariate → adjusted → direct) | MacKinnon, D.P., Krull, J.L. & Lockwood, C.M. (2000). "Equivalence of the mediation, confounding and suppression effect." *Prevention Science*, 1(4): 173–181. | Equations 1–4 |
| Mosley-Chen analytical framework | Mosley, W.H. & Chen, L.C. (1984). "An analytical framework for the study of child survival in developing countries." *Population and Development Review*, 10(Supplement): 25–45. | Full paper |

**Known limitation:** The decomposition uses standard weighted probit, not the recursive bivariate probit framework. This is acknowledged in the script and in the original manuscript's limitations section. A future revision would compute mediation effects within the RBVP joint likelihood (see Critical Review PDF, item #9).

---

## Type B literature gap (acknowledged for future work)

These critique papers are not yet in the user's reference folder and not cited in the manuscript. They are the central modern critique of the IV identification strategy and should be acknowledged in any future write-up:

- **Angrist, J.D. (2014). "The Perils of Peer Effects." *Labour Economics*, 30: 98–108.** — canonical critique of leave-one-out community-mean instruments.
- **Betz, T., Cook, S.J. & Hollenbach, F.M. (2018). "On the use and abuse of spatial instruments." *Political Analysis*, 26(4): 474–479.** — "spatial instruments cannot be valid instruments."

Both papers should be added to the reference folder. They are the structural reason the original PLOS ONE / SSM-Population Health submissions were rejected: reviewers in econ/political-science journals consider these critiques canonical and the original manuscript did not engage with them.

---

## Reference completeness checklist

| Audit Type-A gap | Status |
|---|---|
| Han & Vytlacil (2017) — identification with exclusion | ✓ documented here |
| Mourifié & Méango (2014) — critique of Wilde identification | ⚠ relevant if claiming functional-form identification; not needed for current pipeline (which uses exclusion) |
| Wilde (2000) — identification without exclusion | ⚠ as above |
| Acerenza, Bartalotti & Kédagni (2023) — testable implications | ✓ removed from decorative citation in IV Validity; planned for Phase D |
| Conley, Hansen & Rossi (2012) — plausibly exogenous | ✓ documented here |
| Terza et al. (2008, 2018) — 2SRI | ✓ documented here |
| Wooldridge (2015) — control function | ✓ documented here |
| McGovern et al. (2015) — copula sensitivity | ✓ documented here |
| Klein et al. (2019) — copula bivariate probit | ✓ documented here |
| Lee, Moreira, Porter & Yap (2022) — modern weak IV | ✓ noted in IV Validity caveat |

| Audit Type-B gap | Status |
|---|---|
| Angrist (2014) — perils of peer effects | ⚠ acknowledged; not yet in ref folder |
| Betz et al. (2018) — spatial instruments | ⚠ acknowledged; not yet in ref folder |

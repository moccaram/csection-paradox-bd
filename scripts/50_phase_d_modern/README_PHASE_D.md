# Phase D — Modern causal inference layer

Four sensitivity / diagnostic methods layered on top of the main RBVP pipeline
(`scripts/40_causal_main/`). Each tests a different aspect of the identifying
assumptions or quantifies their fragility.

## Scripts in execution order

| Order | Script | What it tests | Cost | Key output |
|---|---|---|---|---|
| 1 | [51_evalue.R](51_evalue.R) | Strength of unmeasured confounding required to overturn the RBVP ATE | ~30 s | `outputs/phase_d/evalue_csection.csv` |
| 2 | [54_chow_descriptive_break.R](54_chow_descriptive_break.R) | Predetermined Chow test of structural break at 2011 | ~10 s | `outputs/phase_d/chow_test_2011.csv` |
| 3 | [52_sensemakr.R](52_sensemakr.R) | Cinelli-Hazlett OVB partial-R² robustness value, per wave | ~1–3 min | `outputs/phase_d/sensemakr_summary.csv` |
| 4 | [53_acerenza_inequalities.R](53_acerenza_inequalities.R) | 6 testable inequalities of the bivariate probit identifying assumptions | ~2–5 min | `outputs/phase_d/acerenza_test_2022.csv` |

## How each script reads the 2022 RBVP-significant headline

| Method | Question | Verdict on the −1.51 pp result |
|---|---|---|
| E-value | What strength of unmeasured confounder would nullify? | An E-value near 1 means a weak confounder would suffice |
| Chow | Is there a real break at 2011? | Underpowered at T=6, but the visual is unambiguous |
| sensemakr | What partial R² could overturn it? | RV benchmarked against observed covariates |
| Acerenza | Are the bivariate probit's identifying assumptions consistent with the data? | One or more inequality violations would reject |

## Provenance

- Headline RBVP ATE comes from [`outputs/causal_main/Formal_ATE_Results.csv`](../../outputs/causal_main/Formal_ATE_Results.csv) (produced by `41_rbvp_main.R`).
- Master input data: [`outputs/causal_main/data_step1_complete.rds`](../../outputs/causal_main/) (after Phase 1 cleaning) and `data_with_instruments.rds` (after instrument construction).
- Descriptive trajectory: [`data/processed/descriptive/P1_Csec_Trends_All.csv`](../../data/processed/descriptive/).

## References

- VanderWeele TJ, Ding P (2017). Sensitivity Analysis in Observational Research: Introducing the E-Value. *Annals of Internal Medicine* 167(4):268-274. doi:10.7326/M16-2607
- Cinelli C, Hazlett C (2020). Making sense of sensitivity: extending omitted variable bias. *JRSS-B* 82(1):39-67. doi:10.1111/rssb.12348
- Acerenza S, Bartalotti O, Kédagni D (2023). Testing identifying assumptions in bivariate probit models. *Journal of Applied Econometrics* 38(4):529-545.
- Chow GC (1960). Tests of equality between sets of coefficients in two linear regressions. *Econometrica* 28(3):591-605.

# PIPELINE_GRAPH.md

**Project:** C-Section RBVP Pipeline — Data Flow Reference
**Updated:** 2026-05-22

Single canonical map of: which script reads what, which script writes what.

---

## Execution order

Scripts must run in this order; later scripts depend on outputs from earlier ones.

```
┌─────────────────────────────────┐
│  RAW DATA (DHS / BBS)           │
│  /datasets/data.csv             │
└──────────────┬──────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────┐
│  SCRIPT 1 DATA PREPARATION MASTER.R                          │
│  Reads:  datasets/data.csv                                   │
│  Writes: outputs/data_step1_complete.rds                     │
│          outputs/maternal_health_data.{rds,csv}              │
└──────────────┬───────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────┐
│  SCRIPT 2 VARIABLE SELECTION ENSEMBLE.R                      │
│  Reads:  outputs/data_step1_complete.rds                     │
│  Writes: outputs/Recommended_Control_Sets.rds                │
│          outputs/Control_Selection_*.csv                     │
└──────────────┬───────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────┐
│  script_3_rebuilt.R   ⭐ MAIN PIPELINE                       │
│  Reads:  outputs/data_step1_complete.rds                     │
│          outputs/Recommended_Control_Sets.rds                │
│  Writes: outputs/data_with_instruments.rds                   │
│          outputs/Formal_ATE_Results.csv      ⭐               │
│          outputs/FIXED_Sequential_Results.csv                │
│          outputs/FIXED_Confounder_Decomposition.csv          │
│          outputs/FIXED_Mediator_Decomposition.csv            │
│          outputs/LR_Test_Endogeneity.csv                     │
│          outputs/FirstStage_Diagnostics.csv                  │
│          outputs/Missing_Data_Report.csv                     │
│          outputs/Direction_Correction_Log.csv                │
│          outputs/Sample_Characteristics.csv                  │
│          outputs/Naive_Probit_Comparison.csv                 │
│          outputs/Full_Regression_Tables.csv                  │
└──────────────┬───────────────────────────────────────────────┘
               │
               ├─────────────────────────────┬────────────────────────────┬─────────────────────────────┐
               │                             │                            │                             │
               ▼                             ▼                            ▼                             ▼
┌──────────────────────────┐ ┌─────────────────────────────┐ ┌──────────────────────────┐ ┌────────────────────────────┐
│ TWO-STAGE RESIDUAL       │ │ FORMAL IV ASSUMPTION         │ │ COPULA SENSITIVITY       │ │ PHASE3_CONLEY_FIXED.R       │
│ INCLUSION.R              │ │ VALIDITY TESTS.R             │ │ ANALYSIS.R               │ │                             │
│                          │ │                              │ │                          │ │                             │
│ Reads:                   │ │ Reads:                       │ │ Reads:                   │ │ Reads:                       │
│  data_step1_complete.rds │ │  data_step1_complete.rds     │ │  data_step1_complete.rds │ │  data_with_instruments.rds  │
│  Recommended_Control...  │ │  Recommended_Control...      │ │  Recommended_Control...  │ │  Recommended_Control...     │
│  Formal_ATE_Results.csv  │ │  FirstStage_Diagnostics.csv  │ │  (and creates IVs)       │ │  (FIX: uses LPM-2SLS, no    │
│                          │ │                              │ │                          │ │   longer reads Formal_ATE   │
│                          │ │                              │ │                          │ │   nor FirstStage csv)       │
│                          │ │                              │ │                          │ │                             │
│ Writes:                  │ │ Writes:                      │ │ Writes:                  │ │ Writes:                      │
│  2SRI_Full_Results.csv   │ │  IV_Balance_Table.csv        │ │  Copula_ATE_Compari...  │ │  Conley_IV_Estimates_LPM.csv│
│  2SRI_Summary_Compa...   │ │  IV_Balance_Summary.csv      │ │  Copula_Rho_Compari...  │ │  Conley_Full_Curves.csv     │
│  2SRI_Full_Coeffic...    │ │  IV_Reduced_Form.csv         │ │  Copula_AIC_Compari...  │ │  Conley_Breakdown_Cor...    │
│                          │ │  IV_Placebo_Tests.csv        │ │  Copula_SignFlip_Ch...  │ │  figures/Figure_7_Conley... │
│                          │ │  IV_Validity_Summary.csv     │ │  Copula_Sensitivity_S...│ │                             │
└──────────────────────────┘ └─────────────────────────────┘ └──────────────────────────┘ └────────────────────────────┘
```

---

## Other scripts (downstream / supplementary)

| Script | Reads | Writes |
|---|---|---|
| `SCRIPT 5.R` (visualization) | Multiple outputs above | `figures/Fig1_*.png` ... |
| `PATH DIAGRAM FOR RBVP MODEL.R` | Independent | `Figure_Path_Diagram_RBVP.{pdf,png}` |
| `PHASE3_IV_DIAGNOSTICS.R` | `data_step1_complete.rds` | Additional IV diagnostics |
| `PHASE3B_COPULA_SENSITIVITY.R` | RBVP outputs | Alternative copula tests |
| `PHASE4_HETEROGENEITY.R` | RBVP outputs | Urban/rural, wealth-stratified ATEs |
| `IV_STRESS_TEST_SENSITIVITY.R` | RBVP outputs | IV strength stress tests |
| `GENERATE_FINAL_TABLE.R` | Multiple outputs | Final manuscript table |

---

## Inputs required from outside

For a fresh end-to-end run, the pipeline requires the following inputs in `datasets/`:

- `data.csv` — raw BDHS data (4 waves: 2004, 2011, 2017-18, 2022; ~50–80 columns)
  - Must contain DHS variable codes: `v005`, `v007`, `qncluster`, `v101`, `v102`, `v106`, `v119`, `v161`, `v151`, `v714`, `media_exp`, `v228`, `v221_cat`, `v212_cat`, `v511_cat`, `v613_cat`, `mother_age_birth_category`, `v445_cat`, `b0`, `b4`, `b5`, `b7`, `b11_cat`, `contra_usage`, `m14_category`, `m15_category`, `assistance_delivery_cat`, `m17`, `exclusive_breastfeeding`, `baby_health_check`

The currently used `data_step1_complete.rds` (N=18,903; 36 columns) is the post-standardized cohort (0–24 month observation window).

---

## Runtime budget

Approximate wall-clock at full settings (N_BOOT=200 / N_BOOT=500 as documented):

| Script | Wall-clock estimate |
|---|---|
| `SCRIPT 1` | ~5 min |
| `SCRIPT 2` | ~10–15 min |
| `script_3_rebuilt.R` (N_BOOT=200) | **~4–5 hours** (32 GJRM fits × 200 = 6,400 fits) |
| `TWO-STAGE RESIDUAL INCLUSION.R` (N_BOOT=500) | ~30–60 min |
| `FORMAL IV ASSUMPTION VALIDITY TESTS.R` | ~5 min |
| `COPULA SENSITIVITY ANALYSIS.R` | ~60–120 min |
| `PHASE3_CONLEY_FIXED.R` | <2 min |

For smoke-testing, both `script_3_rebuilt.R` and `TWO-STAGE RESIDUAL INCLUSION.R` accept `N_BOOT=<n>` as an environment variable (e.g., `N_BOOT=5 Rscript ...`).

---

## Production reproduction command

To regenerate every output from scratch:

```bash
cd /media/moccaram/54FA0D06FA0CE6581/CS/rbvp/rbvp/

# Phase 1: data prep + variable selection (~20 min total)
Rscript "scripts/SCRIPT 1 DATA PREPARATION MASTER.R"
Rscript "scripts/SCRIPT 2 VARIABLE SELECTION ENSEMBLE.R"

# Phase 2: main pipeline (4–5 hours)
Rscript "scripts/script_3_rebuilt.R"

# Phase 3: parallel auxiliary scripts (all depend only on Phase 1+2 outputs)
Rscript "scripts/TWO-STAGE RESIDUAL INCLUSION.R" &
Rscript "scripts/FORMAL IV ASSUMPTION VALIDITY TESTS.R" &
Rscript "scripts/PHASE3_CONLEY_FIXED.R" &
Rscript "scripts/COPULA SENSITIVITY ANALYSIS.R" &
wait
```

---

## Folder convention

```
/CS/rbvp/rbvp/
├── scripts/         # All R scripts (fixed versions of /rv/rbvp_revised/)
│   └── _PRE_FIX_BACKUP_2026-05-22/   # Pre-fix versions
├── outputs/         # All generated artifacts
│   ├── figures/     # PNG/PDF figures
│   └── _PRE_REPRO_BACKUP_2026-05-22/  # Pre-rerun outputs (the original /rv/ runs)
├── datasets/        # Input data (raw DHS files)
├── AUDIT_LOG.md     # Preserved audit findings (/CS/AUDIT_LOG.md)
├── CHANGELOG_FIXES.md  # Detailed fix log
├── PIPELINE_GRAPH.md   # This file
└── METHODOLOGY_MAP.md  # Output → reference map
```

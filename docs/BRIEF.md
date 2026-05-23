# The C-Section Paradox: When the Model Rejects Itself

**Mukarram Hosain**
M.Sc. Data Science, Shahjalal University of Science and Technology
github.com/moccaram

*Last updated: 2026-05-23*

---

## Background

In Bangladesh DHS data spanning five survey waves from 2004 to 2022 (33,732 children, 62 predictors), wave-by-wave logistic regression of under-five mortality on a standard set of health-system predictors produces a striking anomaly: the sign of the C-section coefficient reverses across the observation window.

**In 2004:** C-section is associated with higher child mortality.
**In 2022:** C-section is associated with lower child mortality.

Eighteen years, a complete reversal. The pattern is large enough to rule out noise and structured enough to demand a causal investigation.

This brief documents what that investigation yielded. A recursive bivariate probit (RBVP) recovers a statistically significant protective effect of C-section on under-24-month mortality in 2022. Three diagnostic tests then reject the identifying assumptions that licence that estimate. The reframing — outcome, design, data, discipline — is what the work points toward.

The brief is organized for three audiences: social scientists working on observational health data, economists familiar with the identification literature on community-level instruments, and statisticians evaluating the formal diagnostic chain. Each section is anchored in at least one of those vocabularies.

---

## 1. Estimation results

The causal pipeline estimates a recursive bivariate probit (RBVP) on 17,603 children across four DHS waves (2004, 2011, 2017–18, 2022). The model uses the community-level leave-one-out C-section rate as an instrument for individual C-section status, then estimates the average treatment effect on under-24-month mortality via the bivariate-normal CDF (Marra & Radice 2011; Greene 2012). Implementation, audit, and the full diagnostic chain are documented in the supporting log files ([CHANGELOG_FIXES.md](rbvp/rbvp/CHANGELOG_FIXES.md), [AUDIT_LOG.md](AUDIT_LOG.md), [METHODOLOGY_MAP.md](rbvp/rbvp/METHODOLOGY_MAP.md)).

The pipeline produces the following estimates:

| Wave | N | Csec ATE (pp) | 95% cluster-bootstrap CI (pp) | Significant? |
|---|---|---|---|---|
| 2004 | 3,478 | **+0.04** | [−1.32, +1.40] | no |
| 2011 | 4,661 | **+0.56** | [−0.76, +1.88] | no |
| 2017–18 | 4,793 | **+1.14** | [−0.63, +2.91] | no |
| **2022** | **4,671** | **−1.51** | **[−2.83, −0.19]** | **yes (α=0.05)** |

Read naively, the headline is real: in 2022, under the model's assumptions, C-section has a statistically significant **protective** effect of 1.5 percentage points on under-24-month mortality. The 95% confidence interval excludes zero. The sign-flip from 2004 to 2022 is preserved.

The diagnostic tests below show why this point estimate does not warrant a causal interpretation.

---

## 2. Three diagnostic tests, three rejections

Three independent diagnostic tests applied to the same pipeline reject the identifying assumptions on which the section-1 estimates depend.

### 2.1 Cross-instrument placebo: the exclusion restriction is decisively violated

If the community-level C-section rate were a valid instrument for individual C-section status, it should predict C-section uptake but **not** predict the take-up of other treatments (here, antenatal care 4+ visits). The reverse should hold for the ANC instrument.

The full cross-table — using the C-section IV to predict ANC, and the ANC IV to predict C-section — is estimated in every wave:

| Wave | Placebo | Coef | p | Pass? |
|---|---|---|---|---|
| 2004 | IV_csec → ANC | +2.24 | <1e-20 | 🔴 fail |
| 2004 | IV_anc → C-sec | +1.01 | <1e-9 | 🔴 fail |
| 2011 | IV_csec → ANC | +0.76 | <1e-13 | 🔴 fail |
| 2011 | IV_anc → C-sec | +0.51 | <1e-8 | 🔴 fail |
| 2017–18 | IV_csec → ANC | +0.74 | <1e-20 | 🔴 fail |
| 2017–18 | IV_anc → C-sec | +0.65 | <1e-18 | 🔴 fail |
| 2022 | IV_csec → ANC | +0.48 | <1e-11 | 🔴 fail |
| 2022 | IV_anc → C-sec | +0.59 | <1e-14 | 🔴 fail |

**Every cell fails. Eight of eight.** The community-level IVs are not treatment-specific — they reflect general healthcare access at the cluster level, and that general access affects everything downstream of healthcare access. The IV cannot satisfy the exclusion restriction.

### 2.2 Hausman test: there may not have been endogeneity to correct

Using the Two-Stage Residual Inclusion (Terza 2018; Wooldridge 2015), the significance of the included first-stage residual in the second-stage probit is the Hausman-style test for endogeneity. If C-section status is genuinely endogenous, the residual coefficient should be significant.

| Wave | C-section residual p | Endogeneity? | ANC residual p | Endogeneity? |
|---|---|---|---|---|
| 2004 | 0.195 | no | 0.745 | no |
| 2011 | 0.214 | no | 0.973 | no |
| 2017–18 | 0.435 | no | 0.225 | no |
| 2022 | **0.978** | **no** | **0.035** | yes |

Only one of eight cells (2022 ANC) shows statistical endogeneity. For C-section specifically — the variable the entire IV machinery was built to correct for — the Hausman test cannot reject the null of exogeneity in any wave.

This is a substantive finding independent of any of the technical bugs above. The residual-coefficient test results come from the (non-bootstrap) point estimation; cluster-bootstrap fixes do not change them. If the 2SRI Hausman test is correct, the recursive bivariate probit may have been deployed to correct a problem the data cannot detect.

### 2.3 Copula sensitivity: the result depends on the dependence structure

The RBVP assumes joint normality of the latent errors. McGovern et al. (2015) and Klein et al. (2019) propose checking this by re-fitting the model under alternative copulas — Gaussian, Frank, Clayton, Gumbel — and comparing signs.

| Wave | Treatment | Gaussian | Frank | Clayton | Signs consistent? |
|---|---|---|---|---|---|
| 2004 | C-sec | −0.025 | −0.009 | −0.016 | ✓ |
| 2011 | C-sec | −0.008 | +0.018 | −0.021 | ⚠ flip |
| 2017–18 | C-sec | +0.015 | +0.021 | −0.010 | ⚠ flip |
| 2022 | C-sec | −0.003 | +0.002 | −0.017 | ⚠ flip |

The Gumbel copula did not converge on this data (likely no upper-tail dependence to identify).

For 2022 C-section: under the Gaussian copula (which is the manuscript's baseline), the ATE is −0.003 — essentially null. Under Clayton, it is −0.017, matching the headline −1.51 pp. The result depends on which dependence structure you assume.

Five of eight cells flip sign across families. The bivariate-normality assumption that licenses the original headline is the assumption under which the headline is least robust.

### What these three say together

The point estimate is recoverable — the math is right. But the identification it depends on is broken on three independent axes: the IV does not satisfy exclusion, the variable does not appear endogenous to begin with, and the result is not robust to the dependence-structure assumption. Three diagnostics, three rejections.

---

## 3. Why the IV breaks: the Duflo framing

The cleanest way to explain why a community-level leave-one-out instrument fails is to follow the framework in Duflo's MIT 14.310x Lecture 21. An instrument needs three things: (i) it predicts the treatment, (ii) it is randomly assigned or as-good-as-random, and (iii) it has **no direct effect on the outcome** — what economists call the exclusion restriction.

Conditions (i) and (ii) are testable. Condition (iii) is not — it must be argued case by case. As Duflo puts it: *"You could prove yourself wrong, but you're never going to be able to prove yourself right."*

The cross-instrument placebo above is precisely the test that proved this IV wrong.

The three classroom analogies in Duflo's lecture map directly onto the C-section project:

- **Deworming pills and contagion.** Children in schools where many got pills had better outcomes — even children who didn't get the pill — because worms are contagious. The IV's effect spilled over through a channel other than the individual treatment.
- **Laptops as an IV for education.** A laptop might keep a child in school *and* help them study *and* hinder their studies. Multi-channel violations of exclusion.
- **Free meals as an IV for school attendance.** Meals deliver vitamins and iron — they affect cognitive outcomes through nutrition, not just through attendance.

The community-level C-section rate is exactly the same kind of object. Communities with high C-section rates are also communities with better roads, sanitation, postnatal care, and private-sector medical infrastructure. Each of those independently affects mortality. The IV does not isolate the C-section channel; it bundles every aspect of healthcare access in that cluster.

This is the structural critique formalized by Angrist (2014) in "The Perils of Peer Effects" (*Labour Economics* 30:98–108) and by Betz, Cook & Hollenbach (2018) in "On the Use and Abuse of Spatial Instruments" (*Political Analysis* 26(4):474–479). Leave-one-out community means are not exogenous to individual outcomes — they mechanically reflect individual characteristics, and they bundle every cluster-level confound into the instrument.

---

## 4. Who would the −1.51 pp apply to? The LATE problem

Even setting the diagnostic failures aside, IV does not recover the average treatment effect on the full population. It recovers the **local average treatment effect** on the compliers — the subset of people whose treatment status was actually changed by the instrument (Imbens & Angrist 1994; Angrist, Imbens & Rubin 1996).

For the community-level C-section IV, the compliers are women whose individual C-section decision was driven by their community's C-section culture — not women who needed a C-section for a medical indication. These are precisely the women in the demand-driven, elective, private-sector segment of the population. They are not the women for whom under-24-month mortality is the policy-relevant outcome. They are healthy women undergoing low-risk surgery, and the salient outcomes for them are not mortality.

So even if the IV were valid, the −1.51 pp would describe a population segment for which the question we have been asking — does C-section reduce mortality? — is no longer the right question. Which is the same conclusion the diagnostic tests pointed to: this design cannot answer the question we set out to answer.

---

## 5. The data-generating process changed under the model

The 2004 and 2022 worlds are not the same place.

In 2004, Bangladesh's national C-section rate was around 3% (Khan et al. 2017, Matlab HDSS). The binding constraint was access. Women who reached a facility for surgery were those with life-threatening complications. The selection mechanism was severity of indication.

In 2022, the C-section rate was 45% — among the highest in the world (Sujon et al. 2025). The binding constraint had shifted from access to demand. The private-sector share of deliveries had grown from roughly 40% in 2004 to over 85% in 2022, with provider incentives driving elective surgeries on low-risk, urban, educated women. The Bangladesh government acknowledged this directly: since 2020, all health facilities have been required to document the medical indication for every C-section performed.

This is a **supply-constrained to demand-driven regime transition**. The instrument's first-stage relationship — community rate predicts individual rate — still holds. But what the community-level variation *means* has changed. In 2004 it indexed facility geography. In 2022 it indexes social norms and provider density. An instrument that means different things in different waves cannot identify a single coherent treatment effect across that span.

This is the regime-transition story the previous version of this brief tried to tell. The new pipeline numbers make the story sharper, not weaker. The 2022 RBVP coefficient is significant *under the model's assumptions*. The diagnostic tests show the assumptions are not met. The story is no longer "the result didn't hold" — it is "the result holds in the estimator but the identification was never sound to begin with."

---

## 6. Where the analysis points

When a model is rejected by its own diagnostics, the next question is not *how does one patch the model* — it is *what would actually answer this question?* That is a question about data, design, and discipline.

**Outcome pivot — from mortality to morbidity.** A 2024 systematic review in *Journal of Allergy and Clinical Immunology: In Practice* concludes that cesarean delivery is associated with increased risks of asthma, allergic rhinitis, atopic dermatitis, food allergies, and allergic sensitization in offspring. A nationwide Taiwan cohort (2024) shows elevated hazard ratios for childhood asthma, rhinitis, and atopic dermatitis. A 2025 systematic review in the *American Journal of Obstetrics & Gynecology* synthesizes ten studies on maternal microbial transfer. A 2024 *Scientific Reports* analysis across two cohorts links cesarean birth to lower motor and language development scores in early childhood. A 2024 meta-analysis estimates a 20% relative increase in type 1 diabetes risk. Mortality has moved with secular trends in nutrition, sanitation, vaccine coverage; morbidity has not.

**Design pivot — from spatial instruments to provider variation.** The clean alternative to a community-level IV is provider-level practice variation (Doyle, Graves, Gruber & Kleiner 2015; Doyle, Graves & Gruber 2023; Card, Dobkin & Maestas 2009). Examiner and judge designs are now well documented as a research framework (Chyn, Frandsen & Leslie 2024, NBER WP 32348). Within a hospital, two obstetricians seeing similar patients may have systematically different C-section propensities — and that variation is much closer to as-good-as-random than spatial clustering of community rates. This requires patient-physician linkage, which BDHS does not provide.

**Data pivot — from cross-sectional surveys to linked clinical records.** Bangladesh has two underused infrastructures. The Matlab Health and Demographic Surveillance System (icddr,b, population ~230,000, continuous since 1966) records every birth with detailed health facility data. The Directorate General of Health Services runs DHIS2 across more than 14,000 community clinics, recording deliveries, indications, and outcomes. Neither is currently linkable to the BDHS sample. That linkage is the missing piece — not a more clever econometric strategy.

**Discipline pivot — from post-hoc estimation to pre-analysis plans.** Nosek et al. (2022, *Nature Human Behaviour*) lays out how preregistration calibrates evidence in observational research; Hernán & Robins's target trial emulation framework (2016, with applications now formalized in the `TrialEmulation` R package) provides the structure for what the trial would look like if we could run it. For the next study, the pre-analysis plan goes on OSF before the data is touched, and the analysis follows it.

---

## 7. The policy ask

Bangladesh's C-section rate has crossed the WHO 15% threshold, and Sujon et al. (2025) document that the surge is driven by the private sector, by provider economic incentives, and by patient and family preferences shaped by social norms. The government has responded with a mandatory C-section audit at every facility since 2020. The data infrastructure to evaluate that audit's impact does not yet exist.

The concrete ask is small and specific:

- A linkage between DGHS DHIS2 (which already records every public-sector delivery) and the BDHS sampling frame.
- An evaluation framework registered on OSF before each wave of data becomes available.
- An expansion of the Matlab HDSS model — birth records plus facility records plus 24- and 36-month follow-up — to a second site in a different region.

This is not a methodological frontier in the same sense as developing a new IV. It is the prerequisite infrastructure without which the methodological frontier is unreachable.

---

## 8. Contributions

This study does not produce a clean causal estimate of C-section's effect on child mortality in Bangladesh. That is not a failure of execution — it is the finding.

What it does contribute:

- **A worked example of recognizing when a sophisticated estimator is undermined by its own diagnostics.** The RBVP coefficient is statistically significant under the model. Three independent diagnostic tests reject the model. The methodological move is to surface that contradiction rather than report the point estimate alone.

- **A reproducible, audited pipeline.** Full diagnostic chain, methodology-to-reference map, and reproducibility notes documented in [`CHANGELOG_FIXES.md`](rbvp/rbvp/CHANGELOG_FIXES.md), [`PIPELINE_GRAPH.md`](rbvp/rbvp/PIPELINE_GRAPH.md), and [`METHODOLOGY_MAP.md`](rbvp/rbvp/METHODOLOGY_MAP.md). The production pipeline can be rerun with the documented `N_BOOT` settings to reproduce the numbers in section 1.

- **A concrete roadmap.** The four pivots in section 6 — morbidity outcomes, provider-propensity IVs, DGHS×BDHS linkage, pre-analysis plans — describe a research program that can be executed against Bangladeshi data infrastructure that already exists.

**Correspondence:** moccaram@gmail.com

---

## Reading list (audience-tagged)

**For social scientists working on similar walls.** Sujon et al. 2025 (Bangladesh C-section regime transition); JACI in Practice 2024 (asthma/allergy review); AJOG 2025 (microbiome transfer); Scientific Reports 2024 (cognitive outcomes); Khan et al. 2017 *IJE* (Matlab HDSS); PLOS One 2024–25 (LMIC C-section trends and district disparities).

**For economists and IV methodologists.** Angrist 2014 *Labour Economics* (peer effects critique); Betz, Cook & Hollenbach 2018 *Political Analysis* (spatial IVs); Doyle, Graves, Gruber & Kleiner 2015 *JPE* (ambulance referral IV); Chyn, Frandsen & Leslie 2024 NBER WP 32348 (examiner designs); Card, Dobkin & Maestas 2009 *QJE* (Medicare RDD); Imbens & Angrist 1994 (LATE); Duflo MIT 14.310x Lecture 21 (foundations + worked exclusion violations).

**For statisticians and identification theorists.** Wilde 2000 (full-rank identification); Han & Vytlacil 2017 *J. Econometrics* (identification under exclusion); Mourifié & Méango 2014 *Economics Letters* (Wilde critique); Acerenza, Bartalotti & Kédagni 2023 *JAE* (testable bivariate-probit inequalities); Terza 2018 *HSR* (2SRI); Wooldridge 2015 (control functions); McGovern et al. 2015 *Epidemiology* and Klein et al. 2019 *Stat Med* (copula sensitivity); Conley, Hansen & Rossi 2012 (plausibly exogenous bounds); Lee, McCrary, Moreira & Porter 2022 (modern weak-IV thresholds); Cameron & Miller 2015 (cluster inference); Nosek et al. 2022 *Nat Hum Behav* (preregistration); Hernán & Robins 2016 (target trial emulation).

---

## Technical appendix

- **Data:** Bangladesh DHS waves 2004, 2011, 2017–18, 2022. Effective sample 17,603 children across four waves for the causal pipeline. The 2007 and 2014 waves were excluded for cross-wave comparability of the under-24-month observation window. The descriptive sign-flip analysis used the full five-wave N=33,732.
- **Treatment, instrument, outcome:** Individual C-section status as treatment; community-level leave-one-out C-section rate as instrument (Wilde 2000-style); under-24-month child mortality as outcome.
- **Estimator:** Recursive bivariate probit via `GJRM::gjrm` with `model = "B"` and `margins = c("probit", "probit")`. Average treatment effect on the probability scale via `pbivnorm`. Cluster bootstrap (200 replications) for confidence intervals using DHS cluster_id.
- **Diagnostic tests:** Cross-instrument placebo (Swanson & Hernán 2013); Wooldridge residual-coefficient endogeneity test (Wooldridge 2015 §2.3); copula sensitivity (Gaussian, Frank, Clayton, Gumbel — Gumbel did not converge); LPM-2SLS via `AER::ivreg` with `sandwich::vcovCL` cluster-robust SEs as a separate-scale cross-check.
- **Software:** R 4.x with `GJRM`, `AER`, `sandwich`, `pbivnorm`, `dplyr`, `ggplot2`. No Python or Quarto in the causal pipeline.
- **Status:** Portfolio artifact summarizing methodological findings from a multi-wave RBVP causal-inference pipeline on BDHS data.

---

*Mukarram Hosain — github.com/moccaram — moccaram@gmail.com*

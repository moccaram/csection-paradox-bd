# csection-paradox-bd

**The South Asian C-Section Paradox: Identification diagnostics and the regime-shift problem in Bangladesh maternal-health data.**

A Quarto book documenting a methodological audit of C-section's effect on under-five mortality in Bangladesh, with extensions to India and Pakistan. Built around the question: **what happens when a recursive bivariate probit produces a statistically significant point estimate, and the model's own diagnostic tests reject the identifying assumptions on which that estimate rests?**

## Read the book

The rendered HTML book is at **<https://moccaram.github.io/csection-paradox-bd/>**.

The source `.qmd` chapters are in the repository root; supporting code lives in `scripts/`, data in `data/`, outputs in `outputs/`, and figures in `figures/`.

## What's inside

| Part | Chapters | Topic |
|---|---|---|
| Front matter | [`index.qmd`](index.qmd), [`00-preface.qmd`](00-preface.qmd) | Hook, reading paths, data-access prerequisites |
| **Part I** | `01`–`05` | Descriptive trends, WHO threshold, sector decomposition, wealth gradient, mortality |
| **Part II** | `06`–`15` | RBVP estimation, 2SRI, IV validity diagnostics, copula sensitivity, Conley bounds, modern sensitivity (E-value / sensemakr / Acerenza / Chow) |
| **Part III** | `16`–`19` | Spatial pipeline (DHS GPS + Malaria Atlas travel time), multilevel models, India/Pakistan robustness |
| Conclusion | `20` | Methodological pivot direction |
| Appendices | `appendixA`–`C` | Pipeline graph, bug-fix changelog, audit log |

## Reproduce locally

```bash
git clone https://github.com/moccaram/csection-paradox-bd.git
cd csection-paradox-bd

Rscript scripts/00_setup/install_packages.R
quarto render
```

The full reproduction guide (DHS access, three tiers of reproduction) is preserved at [`notes/REPLICATION_GUIDE.md`](notes/REPLICATION_GUIDE.md).

## License

- Code, derived outputs, and writing: [MIT License](LICENSE).
- Raw BDHS microdata: not included; requires registration with the [DHS Program](https://dhsprogram.com).

## Correspondence

Mukarram Hosain &middot; M.Sc. Data Science, Shahjalal University of Science and Technology
[github.com/moccaram](https://github.com/moccaram) &middot; moccaram@gmail.com

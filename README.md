# owdpublish (scratch prototype)

A reviewed, open data publishing pipeline for the WASH sector, built as a scratch prototype on 2026-09-06. Nothing here is production code, and the repository is not maintained. It is public as evidence for our request to the SDSC 3rd National Call 2026, where the pipeline now has the working name fairkit.

Lars Schöbitz built it in one session with Claude Code, an AI coding agent. The commits carry an `Assisted-by:` trailer. Claude was asked to work as the engineer the SDSC might assign to the project, so `docs/PLAN.md` and `docs/DECISIONS.md` are written from that point of view. No SDSC staff took part. The people, organisations and data in the demo are invented.

The pipeline, end to end:

```
submit ──> clear ──> build ──> check ──> review ──> publish ──> register
 (form)   (rights,   (washr    (contract  (named    (DOI,       (thin
          consent,   package)  + floor)   reviewers  data       registry,
          PII scan,             + agent    + agent    paper,     exports
          delete raw)           report)    logs)      site)      outward)
```

Every step writes a versioned artifact into the package (`review/`, `inst/metadata/`, `inst/AI_USE.yml`), so the process is reproducible and disclosed by construction.

## What is real and what is a stub

| Step | Status in this prototype |
|---|---|
| Intake (`owd_submit`) | Real: manifest validation, staging directory with restricted permissions, queue |
| Clearance (`owd_scan_pii`, `owd_clear`) | Real heuristics (emails, phones, names, GPS precision, birth dates, ID numbers), recorded decision, raw deleted; the language model hook is a stub |
| Build (`owd_build_package`) | Real: drives washr 1.1.0 (raw data, dictionary, roxygen, README, website config, CI, DESCRIPTION, citation, JSON-LD) |
| Contract check (`owd_contract_check`) | Real: dictionary against data |
| Metadata model and exports (`owd_export_metadata`) | Real: one model rendered to Frictionless Data Package, Croissant JSON-LD, schema.org JSON-LD |
| Required tier (`owd_required_checks`) | Real: a minimal publication floor modelled on pkgreview |
| Agent review (`owd_agent_review`) | Stub: deterministic advisory checks written with the header a real model run would carry (model, prompt hash, run id) |
| Reviewer credit (`owd_credit_reviewer`) | Real: adds the reviewer with the `rev` role to DESCRIPTION |
| AI use statement (`owd_ai_statement`) | Real: aggregates git trailers and agent report headers into `inst/AI_USE.yml` and checks it |
| Data paper (`owd_data_paper`) | Real: generated from the package with a figure from code; rendered when Quarto or rmarkdown is available |
| Registry (`owd_harvest`) | Real: packages, datasets, variables tables, `packages.json` for r-universe, a schema.org DataCatalog, a listing page |
| Zenodo deposit, HDX, Renku connectors | Not built: recorded as the next step in `docs/PLAN.md` |

## Run the demo

```r
source("demo/run_demo.R")
```

It creates a synthetic household water survey with fake personal data, pushes it through every step, and leaves the result under `demo/out/`.

## Layout

- `R/` the pipeline functions, one file per step
- `inst/templates/` the submission manifest, the clearance checklist, the reviewer report, the issue templates
- `inst/workflows/` GitHub Actions for the review tier, the weekly harvest, and publication
- `docs/` the plan, the architecture, the decisions
- `demo/` the end to end run
- `tests/` a few tests for the parts that must not regress

## Findings while building it (2026-09-06)

- washr 1.1.0 drives the whole scaffold non interactively once the working directory and the usethis project are set; all fourteen steps pass. It is the right thing to wrap.
- `usethis::create_package()` refuses to run inside another git project without a prompt, so the pipeline writes the skeleton with desc. In production the package repository is created first on GitHub and cloned, which avoids this.
- The README template renders in-process with pkgload and rmarkdown; `devtools::build_readme()` in a callr subprocess failed, and the template makes a network request during render that fails offline without stopping the render.
- A usethis step creates `.git/hooks/` in a package that has no repository yet. A "does .git exist" check then skips `git init` and commits fall through to the parent repository. The pipeline now checks for `.git/HEAD`. Worth a note in the review standard.
- Dates in ISO form match a naive phone number pattern; the sensitivity scan excludes them explicitly.
- The registry harvest works on a directory of packages with no network; the weekly workflow only adds the cloning.

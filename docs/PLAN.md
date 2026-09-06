# Plan

Written from the point of view of an SDSC engineer at the start of the Proof of Concept cycle. No SDSC staff wrote it (see the README). Six months, one engineer at about half time, the openwashdata team on the other side of the table.

## Weeks 1 to 4: understand and freeze the contract

- Read the existing toolchain (washr 1.1.0, pkgreview 1.6.0, the owdata design). Decide what the pipeline wraps and what it replaces. Decision: wrap washr, do not fork it.
- Write the submission manifest and the clearance policy with the team (this repository: `inst/templates/submission.yml`, `inst/templates/clearance-checklist.md`).
- Agree the publication floor with the review standard (the required tier in `R/review.R` mirrors pkgreview's checklists).
- Pick the staging service with ETH (an access controlled share is enough for the pilot; the pipeline only needs a directory it can read and delete from).

## Weeks 5 to 12: mechanical layer

- Contract check: dictionary against data (done here in `R/contract.R`).
- One metadata model with three renderers (done here in `R/metadata.R`): Frictionless Data Package, Croissant, schema.org.
- Required tier as a GitHub Action (`inst/workflows/review-tier.yaml`).
- Agent review as a versioned artifact (`R/review.R`); replace the stub with a real model run behind a vendor neutral interface; build the evaluation set from the published packages.
- AI use statement generated and checked (`R/disclosure.R`).

## Weeks 13 to 20: review and publication

- Open review on GitHub: issue templates, reviewer template, credit in DESCRIPTION (`R/review.R`).
- Data paper generated from the package with figures from code (`R/paper.R`), rendered in the openwashdata brand through quarto-owd.
- Zenodo deposit with the DataCite record built from the metadata model (not built here).
- Five pilot submissions through the whole pipeline; editor hours logged per submission.

## Weeks 21 to 26: registry, exports, report

- Registry harvest and exports (`R/registry.R`): packages.json for r-universe, a Zenodo community, HDX where in scope, Renku data connectors, a sitemap for Google Dataset Search.
- The conditions report for Full Development: throughput, hours per dataset, rights handling, deposit routes.

## Backlog (not in the PoC)

- Organisation neutral configuration of washr (washr #81).
- Deposit routes to ETH Research Collection and ERIC.
- The journal wrapper: Crossref DOIs for data papers, ISSN, DOAJ. Only at the gate (20 datasets a year, three editors, a funded managing editor fraction).
- A real intake form (Microsoft Forms or a small web app) writing the manifest; this prototype takes the manifest as a file.

## Kill criteria carried over from the openwashdata plan

- More than eight editor hours per dataset after automation: the review design is too heavy.
- Any pressure to promise an impact factor: refuse.

# Architecture

## Components

| Component | Where | Reads | Writes |
|---|---|---|---|
| Intake | `R/intake.R` | a data file and a manifest | `staging/<id>/` (mode 0700), `staging/queue.json` |
| Clearance | `R/clearance.R` | `staging/<id>/` | `cleared/<id>/data.csv`, `cleared/<id>/clearance.json`; deletes the raw file |
| Build | `R/scaffold.R` | `cleared/<id>/` | an R data package made by washr under `packages/<name>/` |
| Contract | `R/contract.R` | `data-raw/dictionary.csv`, `data/*.rda` | `review/contract-report.md`, `review/contract.json` |
| Metadata | `R/metadata.R` | DESCRIPTION, dictionary, CITATION.cff, data | `inst/metadata/datapackage.json`, `croissant.json`, `dataset.jsonld` |
| Required tier | `R/review.R` | the package | `review/mechanical-report.md`, `review/mechanical.json` |
| Agent review | `R/review.R` | the package | `review/agent-report.md` with model, prompt hash, run id |
| Reviewer credit | `R/review.R` | DESCRIPTION | Authors@R with role `rev`; `review/reviewer-<n>.md` |
| AI use statement | `R/disclosure.R` | git trailers, agent report headers, build log | `inst/AI_USE.yml`, `review/ai-use-check.json` |
| Data paper | `R/paper.R` | the package, the reports | `paper/paper.qmd`, rendered HTML |
| Registry | `R/registry.R` | every package | `registry/packages.csv`, `datasets.csv`, `variables.csv`, `packages.json`, `catalog.jsonld`, `index.md` |

## The metadata model

One list built from the package files, rendered three ways. Fields: name, title, description, version, license, DOI, authors (name, ORCID, role), keywords, spatial and temporal coverage, repository URL, site URL, datasets (name, file, rows, columns with name, type, description).

Mapping of dictionary types: `character` to string, `numeric` and `double` to number, `integer` to integer, `logical` to boolean, `Date` to date, `factor` to string with a categories note.

## Trust boundaries

- Raw data with personal information exist only inside `staging/<id>/` and are deleted by `owd_clear()`. The clearance record holds counts, never values.
- Everything after clearance is public by design and lives in a git repository.
- The agent never writes to the data. It writes reports. The deterministic tier is the floor; the agent is advisory; named humans decide.

## Disclosure by construction

- Every agent run writes a header: tool, model, prompt hash, run id, timestamp, inputs.
- Every human commit carries the human as author; agent assisted commits carry an `Assisted-by:` trailer.
- `owd_ai_statement()` aggregates both into `inst/AI_USE.yml`, and `owd_check_ai_statement()` fails the floor when a report exists without a statement entry.
- The data paper prints the statement. The reviewer reports are cited with DOIs.

## What this prototype does not do

Zenodo deposit, the HDX and Renku registrations, the Crossref DOI for the data paper, the intake web form, and the real language model call. Each has a named place in `docs/PLAN.md`.

# What the engineers add, and what stays human (2026-09-06)

Recorded after the prototype, as the answer to "if this took an afternoon, why the engineers?"

## Why the prototype was fast

- The hard part was already done over three years: the package shape, the review standard, the dictionary convention, the brand, the course that supplies reviewers, fifty packages that fix the contract. The speed is evidence of readiness, not of triviality.
- The prototype is a happy path: one machine, one dataset, no users, no attackers, no time passing. That is exactly the SDSC's definition of a Proof of Concept: the need is understood, the conditions for operational deployment are not.

## What the engineers do that a prototype cannot

- Make it run for strangers, for years: identity and permissions on the intake, secrets for the review bot, retention and deletion that hold up to an audit, monitoring, backups, rate limits, cost, a threat model for a server that receives data about people abroad.
- Verify the exports against the reference implementations (frictionless-py, mlcroissant, the Dataset Search validator) and keep the model stable while the standards move.
- Evaluate the agent layer honestly: a labelled set from the published packages, what the model catches and what it invents, where it must never decide.
- Build what was stubbed: the Zenodo and DataCite deposit, HDX and Renku registration, the intake form, the review bot as a GitHub App.
- Stand in as the institutional second maintainer and carry the architecture into the SDSC's own platforms.

## Things the applicant may not know exist (to hand over as questions)

- WebAssembly in the browser: the contract check and the sensitivity scan could run inside the submitter's browser before upload, so personal data are screened before they leave the submitter's machine. A Rust validator compiled to WebAssembly does this; the tidyverse data dictionary CLI is already Rust. The strongest argument for a language beyond R in the service layer.
- SHACL and machine readable policy: the SDSC's ORDES group writes governance rules as SHACL shapes; the clearance checklist can be one such shape.
- A polyglot boundary chosen on purpose: R where the community and the packages are; Python for the reference validators and language model tooling; a small TypeScript GitHub App as the review bot; Rust or WebAssembly for a validator that runs anywhere without R.
- Statistical disclosure control beyond pattern matching (k-anonymity on microdata, as HDX runs with sdcMicro); identity federation with ETH login; federated catalogues (FAIR Data Points, DCAT 3) instead of a portal; supply chain hygiene for the GitHub Actions that publish on our behalf.

## How the request leaves space for them

- Hand over the contract and the questions, not the code: the manifest, the checklist, the floor and the metadata model are the contract; the prototype is a reference implementation they may throw away.
- Open design questions named in the request: the intake architecture and threat model, where R ends and a service language begins, the agent evaluation design, the registry federation. Architecture decision records with status "open" for the ones the engineer owns.
- Use the SDSC's Understand and Experiment phases before Build. Put the intake form in front of two data stewards before anyone codes it.

## The human side while machines do the mechanical work

- What stays human: judgment about value (what a dataset is worth, to whom; finding the reviewer network matters more than the mechanical layers), the question asked before the data exist (the idea origin note as the smallest pre-registration), rights and consent decisions, credit and naming, the relationship with the people who hold the data, the methods and provenance section the generator leaves blank on purpose.
- Measure it inside the pipeline: editor hours, reviewer reports, human commits and the AI use statement are artifacts already; the pilot produces evidence about the human share of publishing, a paper in itself and input to the GFRN disclosure work.
- Keep the order that protects judgment: reviewers touch the data before they read the machine report; rotate people through the mechanical steps so they stay legible.
- Treat the reviewer role as a learning role: course graduates become reviewers, the reviewer report is a competency artifact, and the DIRECT framework gives the competencies a name and a level.

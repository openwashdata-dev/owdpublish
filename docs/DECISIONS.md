# Decisions

One line each, dated, as the engineer would keep them.

- 2026-09-06 Wrap washr, do not fork it. The pipeline calls washr's exported functions in order and records what each did. Anything washr should do differently becomes a washr issue.
- 2026-09-06 The manifest is a file, the form comes later. A YAML manifest with ten fields is enough to prove clearance and build; the web form is a thin writer of that file.
- 2026-09-06 Custody is short. Raw data live in one directory with restricted permissions, and clearance deletes them. The record keeps counts, never values.
- 2026-09-06 One metadata model, three renderers. Frictionless for tools, Croissant for the AI catalogues, schema.org for search. No DCAT-AP CH: the data are not Swiss government data.
- 2026-09-06 The deterministic tier is the floor. The agent report is advisory and carries its own provenance header. Named reviewers decide.
- 2026-09-06 Thin registry, no portal. Tables plus JSON that existing catalogues can harvest. The listing page is static.
- 2026-09-06 The AI use statement is generated, then checked. It is never written by hand first.
- 2026-09-06 The data paper is generated from the package; the author writes only the methods and provenance section and the limitations. Figures come from code chunks.
- 2026-09-06 Reviewer credit goes into DESCRIPTION with the `rev` role, as rOpenSci does, so it travels with the package into every export.

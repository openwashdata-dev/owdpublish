# Clearance checklist

Run by the openwashdata team before any data leave the staging area. Every line is recorded in `clearance.json` with a pass or fail; the record holds counts, never values.

1. Rights. The submitter has confirmed the right to license the data under CC BY 4.0, and the rights holder is named.
2. Consent. If the data contain personal information, the manifest states informed or aggregated consent. "None" with personal data refuses the submission.
3. Sensitivity scan. Heuristic scan for emails, phone numbers, names, identity numbers, precise GPS, birth dates. A language model assisted scan runs on a sample when configured. Every finding gets an action: drop, round, band.
4. Human check. A team member reads the column list and the first rows and adds or removes actions.
5. Decision. Cleared or refused, with the name of the person who decided and the time.
6. Custody ends. The raw file is deleted from the staging area whatever the decision. The cleared file is the only copy that continues.

# Merge Requests - Personal Lessons

## Description length

- `.ai/merge-requests.md` says to keep every template section. Keep them, but scale the prose
  inside them to the diff: fill a section with one sentence when one sentence covers it. Keeping
  a section is not a reason to pad it. See `~/.agents/docs/writing-style.md` § "MR Descriptions"
  for the word ceilings.
- Do not restate blast-radius reasoning, rejected options, or distiller/tooling internals in the
  description. A reviewer who wants that detail reads the linked issue.
- Reviewers do complain about this (gitlab-org/gitlab!253611: "MR description is too long (agents
  love doing that)"), so treat over-long descriptions as a defect, not a stylistic preference.

## Docs preview

- After pushing a change that touches `doc/**`, trigger the `review-docs-deploy` manual CI job on the MR's latest pipeline so the live docs preview reflects the update. The preview is NOT auto-deployed; each doc push needs a fresh trigger. Preview URL pattern: `https://docs.gitlab.com/upstream-review-mr-ee-<mr_iid>/<doc-path-without-.md>/`.

## Duo review replies

- Address `@GitLabDuo` explicitly when replying to its review findings so it can verify the evidence or updated branch; keep the discussion unresolved until it responds.

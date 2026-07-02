# Merge Requests - Personal Lessons

## Issue state tracking

- When an MR closes an issue, update the issue's status as work progresses (not only at the end). Set the status, NOT the `workflow::*` label — the label is kept in sync automatically from the status.
- Typical status progression for issue-backed MR work:
  - "In dev" — actively implementing, while any MR is still in progress.
  - "In review" — only once ALL of the issue's MRs are in review, closed, or merged. If any MR is still in dev, keep the issue "In dev".
  - "Complete" — MR(s) merged / issue closed (usually set automatically on close).

## Docs preview

- After pushing a change that touches `doc/**`, trigger the `review-docs-deploy` manual CI job on the MR's latest pipeline so the live docs preview reflects the update. The preview is NOT auto-deployed; each doc push needs a fresh trigger. Preview URL pattern: `https://docs.gitlab.com/upstream-review-mr-ee-<mr_iid>/<doc-path-without-.md>/`.

# Merge Requests - Personal Lessons

## Docs preview

- After pushing a change that touches `doc/**`, trigger the `review-docs-deploy` manual CI job on the MR's latest pipeline so the live docs preview reflects the update. The preview is NOT auto-deployed; each doc push needs a fresh trigger. Preview URL pattern: `https://docs.gitlab.com/upstream-review-mr-ee-<mr_iid>/<doc-path-without-.md>/`.

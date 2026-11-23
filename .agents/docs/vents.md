# Agent vents

Friction items recorded by the OpenCode `vent` plugin for personal and non-GitLab workflows.

## SSH commit signing fails without an actionable 1Password prompt

### Friction

Git's configured 1Password SSH signer returned an error after pre-commit checks succeeded in both a non-interactive shell and a tmux login shell. The commit did not exist and the validated changes stayed staged.

### Context

Signing the third standalone RuboCop cleanup commit before opening its merge request.

### Evidence / Reproduction

`git commit` reported `error: 1Password: agent returned an error` and `fatal: failed to write commit object`; using a tmux login shell did not change the outcome.

### Suggested Improvement

Surface whether the signer is waiting for user approval, denied, or unavailable so the agent can request the right manual step without rerunning hooks.

<details>
<summary>Session metadata</summary>

- **Recorded**: 2026-11-21T12:18:52.457Z
- **Category**: `permissions`
- **Directory**: `/Users/pedropombeiro/gitlab-development-kit/gitlab`
- **Repository**: `git@gitlab.com:gitlab-org/gitlab.git`
- **Branch**: `master`
- **Session**: `ses_e078f5dbbffeKyMV2iCmGWE42E`

</details>

## Artifact collector can reject ZIPs that pass direct integrity checks

### Friction

The latest unit-b collector failed before its script while downloading shard 35/36, but downloading the same job's artifact directly returned the expected byte count and `unzip -tq` passed. Rebuilding earlier shards moved the failure to a different archive each time.

### Context

Diagnosing the remaining blocking CI failure on GitLab MR !273235 after two collector retries.

### Evidence / Reproduction

Pipeline 3097430868; collector job 18248046815; producer job 18245618360; artifact byte count 4179166. Related known CI health issue: <https://gitlab.com/gitlab-org/quality/analytics/ci-health-systemic/-/work_items/248>.

### Suggested Improvement

Compare runner-side received bytes and checksum against the stored archive, and distinguish a damaged transfer from a damaged stored artifact before recommending shard regeneration.

<details>
<summary>Session metadata</summary>

- **Recorded**: 2026-11-21T22:10:56.365Z
- **Category**: `tooling`
- **Directory**: `/Users/pedropombeiro/gitlab-development-kit/gitlab`
- **Repository**: `git@gitlab.com:gitlab-org/gitlab.git`
- **Branch**: `master`
- **Session**: `ses_e078f5dbbffeKyMV2iCmGWE42E`

</details>

## Stale origin/master makes pre-push hooks lint unrelated changes

### Friction

After a server-side rebase, the worktree's stale origin/master made pre-push hooks include unrelated upstream documentation and JavaScript changes. Fetching the current master ref corrected the merge base and the same push passed with hooks enabled.

### Context

Pushing a targeted revert to GitLab MR !273458 after a UI rebase.

### Evidence / Reproduction

The hook file selection uses git merge-base origin/master HEAD. Before refreshing origin/master, markdownlint, rumdl, and dependency-rules ran on unrelated files and failed. After refreshing it, the MR diff contained 26 files and no Markdown or JavaScript files.

### Suggested Improvement

When pre-push hooks select files outside the intended MR diff after a server-side rebase, check whether origin/master contains the rebase base before investigating the unrelated lint failures.

<details>
<summary>Session metadata</summary>

- **Recorded**: 2026-11-23T11:52:28.874Z
- **Category**: `tooling`
- **Directory**: `/Users/pedropombeiro/gitlab-development-kit/gitlab`
- **Repository**: `git@gitlab.com:gitlab-org/gitlab.git`
- **Branch**: `pedropombeiro/641897/fix-distilled-curl-option-docs`
- **Session**: `ses_e078f5dbbffeKyMV2iCmGWE42E`

</details>

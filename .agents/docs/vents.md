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

# gdkbox job: JOB_ID

Use the same fields for local and GCP jobs. Mark fields that don't apply as `N/A`.

## Identity

- Job ID:
- Mode (`implement`, `test`, `review`, or `investigate`):
- Backend and host (local by default; record GCP approval if applicable):
- Source locator (repository and issue, MR, branch, commit, or patch):
- Base SHA (for an MR, the diff base):
- Source head SHA:
- Integration target SHA, if used:
- Patch SHA-256, if supplied:
- Checkout under test (`base`, `source head`, `prepared merge result`, `patched result`, or `implementation result`):
- Expected checkout commit and tree, if already prepared:

## Execution

- Box name and job checkout path:
- Required runtimes, dependencies, services, and setup checks:
- Ordered commands or one agent task:
- Shell and working directory for each command:
- Agent harness, provider, and pinned model, if applicable:
- Per-command budgets and overall budget:
- Output directory in box and required artifacts:
- Private, durable host artifact destination (outside `$TMPDIR`):
- Checkpoint phases, persistent source path, and approved files to preserve:
- Recovery owner and retention deadline, if needed:
- GCP only: VM runtime limit with `STOP`:

## Results

- Job ID, actual base and tested commit SHAs, and tested tree if applicable:
- Worktree state at test time (identify any tested changes not represented by `HEAD`):
- Outcome (`pass`, `test or verification failure`, `setup failure`, `timeout`, or `artifact collection failure`):
- Outcome detail (record earlier workload status separately if collection failed):
- Actual commands, exit codes, and log locations:
- Verified host artifact locations and mode-specific evidence:
- Latest checkpoint (private path, exact restore base, tree ID, completed phase, and next step):
- Host restore result (`verified`, `failed`, or `N/A` for jobs with no changes to preserve):
- Checks not run and why:
- Watcher or transport failure, if any:
- Cleanup state (released, deleted, or stopped and retained with recovery location, owner, and deadline):

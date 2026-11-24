# Run a manifest-driven repair

Use `scripts/job.py` with Python 3.11 or later and Git. The runner operates on
one disposable checkout and never provisions, pushes, publishes, or deletes
resources. Keep manifests and output in private directories outside the
checkout. Manifests contain trusted operator-authored command arrays, not
commands taken from agent output. Use a separate, new output directory for
each phase or attempt.

## Before provisioning

On the host, use `python3 job.py image MANIFEST IMAGE_OUTPUT` with `crane`
installed and `image` set to the full digest reference in the manifest. Only
provision if it passes. In the guest, pull that same reference. Check the
container image and claim before reusing a box, and test the source access and
checkout ownership as the job user before starting the workload.

## Repair and verification

1. Set `job_id`, `base` (full commit SHA), `input_tree` (the tree after applying
   the input patch), and `input_sha256` in the manifest. Set `edit_paths` to the
   exact tracked paths the agent may repair. Mirror them in the job's
   default-deny OpenCode edit policy in `OPENCODE_CONFIG_CONTENT`. The runner
   checks the exact edit allowlist in this job config. Use an isolated OpenCode
   environment without agent overrides or unrelated policies. Keep the policy
   and prompt operator-owned.
1. Set `required_files` to required checkout instruction and setup files.
   Use optional `setup_checks` to check the harness version and dependencies
   as the job user. The setup checks can require `output_equals` on stdout.
   Set `probe` to the pinned OpenCode invocation with JSON output and a prompt
   to load the exact skills and run the exact read-only commands. For each
   required call, list `tool`, `input`, and optionally `output_contains` in
   `required_tools`. For example, require `skill` with input
   `{"id":"gitlab-coding-principles"}` and `shell` with input
   `{"command":"git rev-parse HEAD"}` and the pinned SHA as output evidence.
   The probe must not edit. It doesn't exercise edits at runtime; the runner
   checks the configured allowlist and rejects out-of-scope tracked changes.
1. Set `repair` to the pinned agent command. Set `checks` to independent,
   non-correcting verification commands. Every command entry has a unique
   `name`, an `argv` list, and a positive timeout in `seconds`. For RuboCop,
   use JSON output and set `rubocop_files` to the expected inspected file
   count for that checkout. Include both the repo-wide target-cop check and
   the all-cops check on changed Ruby files. Use measured limits and add
   headroom in the enclosing `systemd` and VM deadlines for checkpointing and
   collection. The runner provides timeouts per command, not a VM backstop.
1. Under the existing VM-side `systemd` dispatch, run as the job user:

   ```shell
   python3 job.py repair MANIFEST RUN_OUTPUT --checkout CHECKOUT --patch INPUT_PATCH
   ```

   This includes preflight. Use `preflight` instead of `repair` for a
   preflight-only attempt; it applies the input patch, so use a different clean
   checkout for the later repair. Only the probe and repair need the agent
   credential. Declare additional credential variable names in `credential_env`
   so the runner strips them from setup and checks. Start verification in an
   environment with no saved provider credentials.
1. If verification times out, recover the completed checkpoint directory.
   Use a **fresh checkout at the original base**, the same job manifest and
   a new output directory. Change only budgets as needed. Run without an agent
   credential:

   ```shell
   python3 job.py verify-only MANIFEST VERIFY_OUTPUT --checkout CHECKOUT --checkpoint RUN_OUTPUT
   ```

   This validates the checkpoint identity, digest and exact restored tree,
   then reruns the checks without calling OpenCode. Collect the checkpoint and
   phase logs from persistent storage even when verification fails. A
   `verified.json` proves the runner's gates passed; still restore the exact
   tree on the host and review the patch before publication or cleanup.

The [GCP runbook](../../../docs/gdkbox-gcp.md) covers VM ownership, shutdown,
and recovery. The runner assumes the launcher provides the VM deadline,
authenticated handoff, and private artifact transport.

## Validate the launcher integration

Start one approved pilot from a fresh checkout with a known failing input.
Disconnect the host watcher after `systemd` accepts the job. Verify that the
guest finishes the repair and both scans without the watcher, then reconnect
and restore the recovered patch to the exact saved tree on the host. Also
exercise a verification-only resume with no provider credential. Count host
verification as recovery evidence, not as proof that the guest scans passed.

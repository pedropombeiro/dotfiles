# Run GDK jobs on Compute Engine

Use one reusable VM in an approved sandbox project. Use `gcloud compute` to manage the VM, disk, and networking.
`gdkbox` does not manage these resources.

The verified setup runs `gdkbox` inside the VM to manage a Docker container. Use `gdkbox-fleet` for that container's
claim, lifecycle, and dispatch. If you have a separately provisioned VM-native GDK, skip the container-specific steps.
This runbook does not cover installing GDK directly on the VM.

**Stop the VM on timeout. Delete it only after the host verifies the artifacts and restores any checkpoint, or the
user explicitly abandons recovery.** A container claim does not set the VM runtime limit or stop the VM.

## Provision and smoke-test

1. Pass the approved `--project` and `--zone` explicitly. Use Standard provisioning and a persistent boot disk. The
   verified starting point was Ubuntu 24.04 amd64, `e2-standard-8`, and an 80 GB balanced persistent disk. Record the
   project, zone, VM name, and names of any dedicated network resources outside the VM. Pin the workload's Git commit
    and record the GDK image digest if using a container. Before provisioning,
    run the companion's `image` phase against the exact digest for `linux/amd64`.
    Stop on a missing digest or platform mismatch. Never fall back to a tag.
2. For the container setup, install Docker, Ruby, and `gdkbox` on the VM. Pull the official GDK-in-a-box image as a
    distinct, timed stage. Make bootstrap safe to rerun: reuse a container only if its image and claim match the job.
    Use a fresh isolated checkout for each attempt. Check source ownership and access as the job user.
   Keep startup output in the guest journal or serial stream. Redirecting straight to `/dev/ttyS0` lost diagnostics in
   the first run.
3. If using a container, use a plain box without `--docker`. Keep GDK ports on loopback. For startup-script-only tests,
   use no inbound firewall rule and no VM service account. For remote administration, use an approved private path or
   narrowly scoped SSH with a pinned host key. The smoke test used a temporary SSH key and a firewall rule limited to
   the operator's source IP. Allow outbound access for package, image, and provider requests.
4. If using a container, verify `gdkbox up` and container SSH. If the task needs Rails, verify `/-/health` returns
   HTTP 200 with `GitLab OK`. Allow time for startup `502`s to clear. This endpoint verifies the app server responds,
    not database readiness. For an agent job, use the manifest preflight to verify the required skills and exact
    read-only commands in the job checkout. Match the default-deny edit allowlist to the job before dispatch.

## Preserve work across timeouts

- Set `--max-run-duration=60m --instance-termination-action=STOP` as an example
  [Compute Engine runtime backstop](https://cloud.google.com/compute/docs/instances/limit-vm-runtime). Size the limit
  for bootstrap, work, and artifact collection. `STOP` preserves the persistent boot disk but kills running processes.
  Restarting gives a fresh duration budget. Re-resolve the SSH address after restart rather than assuming an ephemeral
  IP stayed the same. Stopped disks still incur charges; record a retention deadline and who will delete them.
- Run long dispatches in a bounded VM-side job such as a transient `systemd-run` service, independent of the SSH
  connection. Use separate deadlines for the workload, dispatch, and VM. Leave time for artifact collection before the
  VM stops. Log the phase and exact exit code before validating it so a timeout isn't reduced to a generic shell
  failure.
- Write stage logs, exit codes, and private work-in-progress checkpoints to persistent storage as work proceeds. Follow
  `gdkbox-workflows` for what to capture and how to verify restore. Save edits before starting verification, not only
  if verification passes. Mark a phase complete only after its checkpoint and phase record are complete. Resume from
  the latest complete checkpoint. For a verification timeout, use the companion's `verify-only` phase in a clean
  checkout from that checkpoint, without an agent or Duo token. Budget large scans separately and allow time
  for recovery inside the VM deadline. A partial JSON report with zero offenses does not pass.
- Copy logs and artifacts off the VM incrementally to a private, durable host directory. Transfer patches and reports
  through an approved artifact path, not guest attributes or serial output. Use
  [GCE guest attributes](https://cloud.google.com/compute/docs/metadata/manage-guest-attributes) for short, non-secret
  stage and result summaries; keep serial output as a fallback. The tested
  `gcloud ... get-guest-attributes --format=json` returned a top-level array. Accept that and the API wrapper:
  `if type == "array" then .[] else .queryValue.items[]? end`. Stop the watcher on explicit success, failure, or a
  startup runner failure, with a bounded wait for each API call. Treat a local DNS, OAuth refresh, or SSH failure as a
  collection problem until you verify guest status and Compute Engine operations.
- For live monitoring, tail the local progress log in a right-hand `tmux split-window -h` pane. On macOS, GNU
  `gtail --pid=RUNNER_PID -F` lets the pane close with the runner, including cleanup. gdkbox 0.1.21 buffers the agent
  transcript until dispatch exits; follow the workload's own log for live progress. A printed artifact directory is not
  proof that results have arrived.

## Configure OpenCode with Duo

These steps apply to agent dispatch through `gdkbox` inside the VM.

- Check `opencode --version` **inside** the box. gdkbox 0.1.21 installed `opencode-ai` 1.19.6; a fresh box did not
  inherit the prior fix. The verified workaround in [gdkbox #20](https://gitlab.com/jotolo_gl/gdkbox/-/work_items/20)
  was to install `@opencode/cli@2.3.0` inside the box with
  `npm install -g --prefix ~/.local @opencode/cli@2.3.0 --force`, then install a filtered OpenCode configuration for the
  GitLab provider. Recheck this workaround on newer releases.
- Use the fleet skill's `scripts/export-opencode-config.mjs` if available. Include only the needed provider, model, and
  portable permission settings. Omit host-only plugins and telemetry endpoints for cloud runs. Check both the host model
  configuration and the provider's model mapping. `gitlab/duo-chat-gpt-6-1-sol` worked with `gitlab-ai-provider` 6.24.0;
  `gitlab-ai-provider` 6.25.0 added `duo-chat-gpt-6-2-astra` and `duo-chat-gpt-6-2-sol`. Scope any explicitly requested
  model override to the box. A generic server error alone doesn't identify a provider outage.
- Use only the dedicated short-lived `GITLAB_GDKBOX_TOKEN`. For remote seeding, send it over authenticated SSH stdin and
  map it to `GITLAB_TOKEN` for `gdkbox set-key` on the VM. Never put it in startup scripts, VM metadata, command
  arguments, or logs. Pre-create the task worktree or allow only the specific operations the task needs. Verify the
  pinned model with a no-tools sentinel before dispatching work.

## Collect results and clean up

1. Confirm the workload exit code and inspect the actual result. For RuboCop TODO removal, keep the private recovery
   checkpoint and full scan report even when offenses remain. Mark a patch ready only after safe `-a` and a separate
   non-correcting repo-wide scan and an all-cops check on the changed Ruby files. Require successful exits,
   expected coverage, and zero offenses. Flag protected migration paths for human review before publication.
2. Verify the host copy and restore the latest checkpoint in a disposable checkout before destructive cleanup. A
   terminal guest status, summary, or exit code does not prove recovery. In an automated runner, make stop and retain
   the default exit path. Enable deletion only after the host checks pass. If collection or restore fails, stop the
   container if present, then stop the VM without deleting it. Keep the persistent disk for the agreed recovery window.
   Record the project, zone, VM, disk, checkpoint path, next step, owner, and retention deadline outside the VM. Remove
   any saved agent token when it is no longer needed. If the deadline approaches and work is still unverified, ask
   whether to extend retention or abandon recovery.
3. Once the host verifies recovery or the user explicitly abandons it, delete the VM and boot disk. Verify they're
   gone before deleting any dedicated firewall rule, subnet, and VPC, then verify each is absent by name. A killed
   shell can skip its exit trap, and a failed CLI request can leave an operation running. Recheck resource state
   before retrying cleanup.

## Verified baseline

The November 2026 sandbox runs verified container SSH, HTTP 200 on `/-/health` after about eight minutes from boot, a
GPT-6.1 Sol no-tools dispatch, and 24 passing resolver specs for
[GitLab #602181](https://gitlab.com/gitlab-org/gitlab/-/work_items/602181). A later direct `Style/EmptyElse` run
inspected 56,407 files and verified that eight offenses remained after safe autocorrection. The scan result was
collected, but the partially corrected worktree was not. A later `Style/EndlessMethod` pilot recovered an exact
OpenCode repair from GCP. The VM's repo-wide scan timed out and the host completed both checks on the restored
tree. End-to-end cloud verification and the reusable runner's live GCP integration still need a fresh pilot.

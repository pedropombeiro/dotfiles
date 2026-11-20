# Run gdkbox on Compute Engine

Use one reusable VM in an approved sandbox project.
**Stop on timeout and delete only after collecting the results or explicitly abandoning recovery.** Use the
`gdkbox-fleet` skill for container ownership and dispatch rules. The VM runtime limit and the container claim are
separate.

## Provision and smoke-test

1. Pass the approved `--project` and `--zone` explicitly. Use Standard provisioning and a persistent boot disk. The
   verified starting point was Ubuntu 24.04 amd64, `e2-standard-8`, and an 80 GB balanced persistent disk. Record the
   project, zone, VM name, and names of any dedicated network resources outside the VM. Pin the workload's Git commit
   and record the GDK image digest.
2. Install Docker, Ruby, and gdkbox on the VM. Pull the official GDK-in-a-box image as a distinct, timed stage. Make
   bootstrap safe to rerun: reuse the existing image, container, and checkout on restart. Keep startup output in the
   guest journal or serial stream instead of redirecting straight to `/dev/ttyS0`, which lost diagnostics in the first
   run.
3. Use a plain box without `--docker`. Keep GDK ports on loopback. For startup-script-only tests, use no inbound
   firewall rule and no VM service account. If you need remote administration, use an approved private access path or
   narrowly scoped SSH with a pinned host key. The smoke test used a temporary SSH key and a firewall rule limited to
   the operator's source IP. Allow outbound access for package, image, and provider requests.
4. Test one layer at a time: `gdkbox up`, SSH into the container, and, if the task needs Rails, `/-/health` returning
   HTTP 200 with `GitLab OK`. Allow time for startup `502`s to clear. This endpoint verifies the app server responds,
   not database readiness. Then run a no-tools agent dispatch before attempting a full workload.

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
- Write stage logs, exit codes, and artifacts to persistent storage as work proceeds. Key checkpoints by base commit and
  task. Mark a phase complete only after its result is recorded. Resume verification from completed autocorrection; if
  autocorrection was interrupted, retry from a clean worktree. A validation-only workload can run directly in the box
  without an agent or Duo token.
- Copy logs and artifacts off the VM incrementally. Use
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

- Check `opencode --version` **inside** the box. gdkbox 0.1.21 installed `opencode-ai` 1.19.6; a fresh box did not
  inherit the prior fix. The verified workaround in [gdkbox #20](https://gitlab.com/jotolo_gl/gdkbox/-/work_items/20)
  was to install `@opencode/cli@2.3.0` inside the box with
  `npm install -g --prefix ~/.local @opencode/cli@2.3.0 --force`, then install a filtered OpenCode configuration for the
  GitLab provider. Recheck this workaround on newer releases.
- Use the fleet skill's `scripts/export-opencode-config.mjs` if available. Include only the needed provider, model, and
  portable permission settings. Omit host-only plugins and telemetry endpoints for cloud runs. Check both the host model
  configuration and the provider's model mapping. `gitlab/duo-chat-gpt-6-1-sol` worked with `gitlab-ai-provider` 6.24.0;
  that provider did not recognize `duo-chat-gpt-6-2-sol`. Scope any explicitly requested model override to the box. A
  generic server error alone doesn't identify a provider outage.
- Use only the dedicated short-lived `GITLAB_GDKBOX_TOKEN`. For remote seeding, send it over authenticated SSH stdin and
  map it to `GITLAB_TOKEN` for `gdkbox set-key` on the VM. Never put it in startup scripts, VM metadata, command
  arguments, or logs. Pre-create the task worktree or allow only the specific operations the task needs. Verify the
  pinned model with a no-tools sentinel before dispatching work.

## Collect results and clean up

1. Confirm the workload exit code and inspect the actual result. For RuboCop TODO removal, require safe `-a`, followed
   by a separate non-correcting repo-wide scan that inspects files and reports zero offenses before exporting a patch.
   Neither a passing resolver test suite nor a timed-out scan qualifies.
2. Preserve local artifacts before teardown. Stop the box and release its claim when finished. On failure, stop the VM
   and keep it only for the agreed recovery window. Remove any saved token from a retained box when it is no longer
   needed.
3. Delete the VM and boot disk when recovery is complete, then any dedicated firewall rule, subnet, and VPC. Verify each
   is absent by name. A killed shell may skip its exit trap; a failed CLI request can also leave an operation running.
   Recheck the resource state before retrying cleanup.

## Verified baseline

The November 2026 sandbox runs verified container SSH, HTTP 200 on `/-/health` after about eight minutes from boot, a
GPT-6.1 Sol no-tools dispatch, and 24 passing resolver specs for
[GitLab #602181](https://gitlab.com/gitlab-org/gitlab/-/work_items/602181). The direct `Style/EmptyElse` run stopped at
its six-minute autocorrection limit. It did not produce a verified offense count or patch. The stop-and-resume workflow
above is the recommended next setup, not a completed recovery test.

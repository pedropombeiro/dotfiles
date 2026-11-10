#!/usr/bin/env zsh
# Run downloaded cask tools through Gatekeeper without removing quarantine.
# Source this file to use approve_casks or approve_bootstrap_apps.

approval_warn() {
  if (( $+functions[_update_warn] )); then
    _update_warn "$*"
  else
    print -u2 -- "warning: $*"
  fi
}

# NSWorkspace avoids sending Apple events to apps or matching process names.
approval_apps() {
  osascript -l JavaScript - "$@" <<'JXA'
ObjC.import('AppKit');
function run(args) {
  const apps = $.NSWorkspace.sharedWorkspace.runningApplications;
  const paths = [];
  for (let i = 0; i < apps.count; i++) {
    const app = apps.objectAtIndex(i);
    if (!app.bundleURL) continue;
    const path = ObjC.unwrap(app.bundleURL.path);
    if (args[0] === 'list') paths.push(path);
    else if (path === args[1]) {
      const pid = String(app.processIdentifier);
      if (args[0] === 'pid') return pid;
      if (args[0] === 'quit' && pid === args[2]) return app.terminate ? 'yes' : 'no';
    }
  }
  return paths.join('\n');
}
JXA
}

approval_needed() {
  local quarantine flags
  quarantine=$(xattr -p com.apple.quarantine "$1" 2>/dev/null) || return 1
  flags=${quarantine%%;*}
  [[ -n $flags && $flags != *[^0-9a-fA-F]* ]] || return 1
  # 0x40 records user consent. Both 0181 and 0381 still need approval.
  (( (16#$flags & 0x40) == 0 ))
}

approve_app() {
  local app=$1 initially_running=$2 pid response
  local -i deadline
  approval_needed "$app" || return 0

  [[ -n $initially_running ]] || { approval_warn "No app-state snapshot; skipping $app"; return 0; }

  if (( ${${(f)initially_running}[(Ie)$app]} )); then
    print -r -- "Leaving already-running app alone: $app (approval may wait until its next restart)"
    return 0
  fi
  pid=$(approval_apps pid "$app") || { approval_warn "Cannot check running state: $app"; return 0; }
  if [[ -n $pid ]]; then
    print -r -- "Leaving already-running app alone: $app"
    return 0
  fi

  print -r -- "Opening $app for macOS approval. Click Open if prompted."
  open -gj "$app" || { approval_warn "Cannot open $app"; return 0; }
  deadline=$(( EPOCHSECONDS + 120 ))
  while (( EPOCHSECONDS < deadline )); do
    pid=$(approval_apps pid "$app") || break
    [[ -n $pid ]] && break
    sleep 1
  done
  if [[ -z $pid ]]; then
    approval_warn "App did not start within 120 seconds: $app"
    return 0
  fi
  # Graceful termination only. Never force-quit or close an existing process.
  response=$(approval_apps quit "$app" "$pid") || response=no
  [[ $response == yes ]] || approval_warn "Could not quit $app; leaving it open."
}

approve_binary() {
  local binary=$1
  [[ -x $binary ]] || { approval_warn "Cask executable is missing: $binary"; return 0; }
  print -r -- "Checking $binary --version. Click Open if macOS asks."
  if ! timeout 120 "$binary" --version </dev/null; then
    approval_warn "Executable check failed or timed out: $binary --version"
  fi
}

approve_casks() {
  local before=$1 initially_running=$2 metadata records token kind target
  local -a artifacts
  [[ -s $before ]] || { approval_warn 'No pre-upgrade cask snapshot; skipping approval.'; return 0; }
  metadata=$(brew info --json=v2 --installed) || { approval_warn 'Cannot list updated casks.'; return 0; }
  records=$(jq -j --slurpfile before "$before" '
    ($before[0].casks | map({key: .token, value: .installed}) | from_entries) as $old |
    .casks[] | select(.installed != null and .installed != $old[.token]) |
    .token as $token | .artifacts[] |
    select(has("binary") or has("app")) |
    $token, "\u0000", (if has("app") then "app" else "binary" end), "\u0000",
    (.target // ""), "\u0000"
  ' <<< "$metadata") || { approval_warn 'Cannot compare cask snapshots; skipping approval.'; return 0; }
  artifacts=("${(@0)records}")
  local -i i
  for (( i = 1; i + 2 <= ${#artifacts}; i += 3 )); do
    token=$artifacts[i] kind=$artifacts[i+1] target=$artifacts[i+2]
    if [[ -z $target ]]; then
      approval_warn "No artifact target for $token; skipping $kind."
    elif [[ $kind == app ]]; then
      approve_app "$target" "$initially_running"
    else
      approve_binary "$target"
    fi
  done
  return 0
}

approve_bootstrap_apps() {
  local app initially_running
  initially_running=$(approval_apps list) || { approval_warn 'Cannot record running apps; skipping approval.'; return 0; }
  for app in /Applications/*.app(N/); do
    approve_app "$app" "$initially_running"
  done
}

zmodload zsh/datetime
if [[ $ZSH_EVAL_CONTEXT == toplevel ]]; then
  if [[ $1 == --bootstrap ]]; then
    approve_bootstrap_apps
  else
    print -u2 'Usage: approve-quarantined.zsh --bootstrap'
    exit 1
  fi
fi

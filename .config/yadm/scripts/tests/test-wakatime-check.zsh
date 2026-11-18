#!/usr/bin/env zsh

# Isolated project-detection checks. No requests reach WakaTime or Wakapi.
set -e
scripts=${${(%):-%x}:A:h:h}
source "$scripts/tests/lib/test-helpers.zsh"
test_sandbox jq
trap test_cleanup EXIT

mkdir -p "$TEST_SANDBOX/scripts/"{checks.d,lib} "$HOME/.wakatime"
cp "$scripts/checks.d/030-wakatime.zsh" "$TEST_SANDBOX/scripts/checks.d/"
cp "$scripts/lib/"{check-helpers.zsh,colors.sh} "$TEST_SANDBOX/scripts/lib/"
check="$TEST_SANDBOX/scripts/checks.d/030-wakatime.zsh"
print -r -- 'import_cfg = ~/.wakatime.base.cfg' > "$HOME/.wakatime.cfg"
export GDK_ROOT="$TEST_SANDBOX/gdk"
mkdir -p "$GDK_ROOT/gitlab/.ai"
print -r -- '# Probe' > "$GDK_ROOT/gitlab/.ai/README.md"
git init -q "$GDK_ROOT/gitlab"
(
  cd "$GDK_ROOT/gitlab"
  git add .ai/README.md
)
export CHECK_TRACE="$TEST_SANDBOX/trace"
export UPDATE_FAILURE_FILE="$TEST_SANDBOX/failures"

test_stub sleep <<'SCRIPT'
#!/usr/bin/env zsh
print sleep >> "$CHECK_TRACE"
SCRIPT

test_stub wakatime-cli <<'SCRIPT'
#!/usr/bin/env zsh
while (( $# )); do
  if [[ $1 == --entity ]]; then
    entity=$2
    shift
  fi
  shift
done
if [[ $entity == "$HOME/.zshrc" ]]; then
  kind=dotfiles
  project=dotfiles
else
  kind=repo
  project=gitlab
fi
print -r -- "$kind" >> "$CHECK_TRACE"
if [[ $PROBE_MODE == backoff || $PROBE_MODE == "backoff-$kind" ]]; then
  print -r -- 'debug log that should not be dumped'
  exit 112
fi
if [[ $PROBE_MODE == error ]]; then
  print -r -- 'API request failed'
  exit 102
fi
[[ $PROBE_MODE == wrong-project ]] && project=incorrect
[[ $PROBE_MODE == repo-is-dotfiles && $kind == repo ]] && project=dotfiles
[[ $PROBE_MODE == missing-heartbeat ]] && exit 0
jq -cn --arg entity "$entity" --arg project "$project" \
  '{message: ("heartbeats: " + ([{entity: $entity, project: $project}] | tojson))}'
SCRIPT
ln -s "$TEST_SANDBOX/bin/wakatime-cli" "$HOME/.wakatime/wakatime-cli"

run_case() {
  export PROBE_MODE=$1
  local expected_rc=$2 expected_trace=$3 expected_skips=$4
  : > "$CHECK_TRACE"
  : > "$UPDATE_FAILURE_FILE"
  test_expect_status "$PROBE_MODE" "$expected_rc" zsh -df "$check"
  test_assert_equal "$PROBE_MODE: calls" "$expected_trace" "$(<"$CHECK_TRACE")"
  local skips=$(grep -c 'skipped: API backoff' "$TEST_SANDBOX/output" || true)
  test_assert_equal "$PROBE_MODE: skips" "$expected_skips" "$skips"
  if (( expected_rc == 0 )); then
    [[ ! -s $UPDATE_FAILURE_FILE ]] || test_fail "$PROBE_MODE: recorded a failure"
    if grep -q 'debug log\|Expected ' "$TEST_SANDBOX/output"; then
      test_fail "$PROBE_MODE: unexpected failure diagnostic"
    fi
  else
    [[ -s $UPDATE_FAILURE_FILE ]] || test_fail "$PROBE_MODE: missing failure record"
  fi
}

run_case success 0 $'dotfiles\nrepo' 0
run_case backoff 0 $'dotfiles\nrepo' 2
run_case backoff-dotfiles 0 $'dotfiles\nrepo' 1
run_case backoff-repo 0 $'dotfiles\nrepo' 1
run_case error 1 $'dotfiles\nsleep\ndotfiles\nsleep\ndotfiles\nrepo\nsleep\nrepo\nsleep\nrepo' 0
grep -q 'WakaTime CLI failed (exit 102)' "$TEST_SANDBOX/output" || test_fail 'missing CLI error diagnostic'
run_case wrong-project 1 $'dotfiles\nrepo' 0
run_case repo-is-dotfiles 1 $'dotfiles\nrepo' 0
run_case missing-heartbeat 1 $'dotfiles\nsleep\ndotfiles\nsleep\ndotfiles\nrepo\nsleep\nrepo\nsleep\nrepo' 0

print -r -- 'PASS: WakaTime project-detection checks'

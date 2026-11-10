#!/usr/bin/env zsh

# Isolated discovery tests. No live health checks or repair actions run here.
set -e
setopt NULL_GLOB
scripts=${${(%):-%x}:A:h:h}
scratch=$(mktemp -d "${TMPDIR:-/tmp}/test-run-checks.XXXXXXXX")
trap 'rm -rf -- "$scratch"' EXIT

# Prevent inherited repository settings from affecting the fixture repository.
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE
export GIT_CONFIG_COUNT=2
export GIT_CONFIG_KEY_0=yadm.auto-alt GIT_CONFIG_VALUE_0=false
export GIT_CONFIG_KEY_1=yadm.auto-perms GIT_CONFIG_VALUE_1=false
export UPDATE_FAILURE_FILE="$scratch/failures"
export CHECK_TRACE="$scratch/trace"

mkdir -p "$scratch/scripts/checks.d"
cp "$scripts/run-checks.zsh" "$scripts/check-helpers.zsh" "$scripts/colors.sh" "$scratch/scripts/"
runner="$scratch/scripts/run-checks.zsh"
checks="$scratch/scripts/checks.d"

fail() {
  print -ru2 -- "FAIL: $1"
  exit 1
}

expect_run() {
  local expected_rc=$1 expected_trace=$2 rc=0
  : > "$CHECK_TRACE"
  : > "$UPDATE_FAILURE_FILE"
  zsh "$runner" > "$scratch/output" 2>&1 || rc=$?
  [[ $rc == $expected_rc ]] || { cat "$scratch/output"; fail "expected exit $expected_rc, got $rc"; }
  [[ $(<"$CHECK_TRACE") == "$expected_trace" ]] || fail "unexpected execution order: $(<"$CHECK_TRACE")"
}

fixture() {
  local name=$1 body=$2
  printf '#!/usr/bin/env zsh\n%s\n' "$body" > "$checks/$name"
  chmod +x "$checks/$name"
}

expect_run 1 ''
grep -q 'No health checks found' "$UPDATE_FAILURE_FILE" || fail 'missing empty-directory diagnostic'

fixture '020-selected.zsh##os.Darwin' 'print selected >> "$CHECK_TRACE"'
fixture '030-inactive.zsh##os.Linux' 'print inactive >> "$CHECK_TRACE"'
fixture '040-editor.zsh~' 'print backup >> "$CHECK_TRACE"'
fixture '.hidden.zsh' 'print hidden >> "$CHECK_TRACE"'
fixture '050-embedded##source.zsh' 'print source >> "$CHECK_TRACE"'
mkdir "$checks/nested"
printf '#!/usr/bin/env zsh\nprint nested >> "$CHECK_TRACE"\n' > "$checks/nested/010-nested.zsh"
chmod +x "$checks/nested/010-nested.zsh"
fixture '010-shared.zsh' 'print shared >> "$CHECK_TRACE"; cd /; setopt NO_GLOB; leaked=yes'
ln -s '020-selected.zsh##os.Darwin' "$checks/020-selected.zsh"
fixture '025-isolation.zsh' '[[ -z $leaked && $options[glob] == on ]] || exit 9; print isolated >> "$CHECK_TRACE"'
expect_run 0 $'shared\nselected\nisolated'

fixture '015-failure.zsh' 'print failed >> "$CHECK_TRACE"; exit 7'
expect_run 1 $'shared\nfailed\nselected\nisolated'
grep -q '015-failure.zsh failed (exit 7)' "$UPDATE_FAILURE_FILE" || fail 'missing failure diagnostic'
rm "$checks/015-failure.zsh"

ln -s missing "$checks/015-broken.zsh"
fixture '016-disabled.zsh' 'print disabled >> "$CHECK_TRACE"'
chmod -x "$checks/016-disabled.zsh"
expect_run 1 $'shared\nselected\nisolated'
[[ $(wc -l < "$UPDATE_FAILURE_FILE") -eq 2 ]] || fail 'invalid entries not reported'
rm "$checks/015-broken.zsh" "$checks/016-disabled.zsh"

fixture '015-warning.zsh' 'source "${0:h:h}/check-helpers.zsh"; print_warn warning; exit "$any_failed"'
expect_run 0 $'shared\nselected\nisolated'
[[ ! -s "$UPDATE_FAILURE_FILE" ]] || fail 'warning was recorded as failure'
fixture '015-warning.zsh' 'source "${0:h:h}/check-helpers.zsh"; print_failure detail; any_failed=1; exit "$any_failed"'
expect_run 1 $'shared\nselected\nisolated'
grep -q '^detail$' "$UPDATE_FAILURE_FILE" || fail 'module detail not preserved'

# Exercise real YADM selection with harmless copies of production filenames.
mkdir -p "$scratch/identity/checks.d"
for module in "$scripts/checks.d/"*.zsh*; do
  [[ -L "$module" ]] && continue
  printf '#!/usr/bin/env zsh\nprint -r -- "${0:t}" >> "$CHECK_TRACE"\n' > "$scratch/identity/checks.d/${module:t}"
  chmod +x "$scratch/identity/checks.d/${module:t}"
done
cp "$scripts/run-checks.zsh" "$scripts/check-helpers.zsh" "$scripts/colors.sh" "$scratch/identity/"
yd() {
  yadm --yadm-dir "$scratch/yadm-config" --yadm-data "$scratch/yadm-data" "$@"
}
yd init -w "$scratch/identity" > "$scratch/yadm-output" 2>&1
yd add "$scratch/identity/checks.d" >> "$scratch/yadm-output" 2>&1
runner="$scratch/identity/run-checks.zsh"
common=$'020-opencode-telemetry.zsh\n025-configs.zsh\n030-wakatime.zsh\n040-agent-doc-links.zsh\n050-skill-lock.zsh\n060-alt-duplication.zsh'
work=$'200-glab-auth.zsh\n210-gdk-wakatime.zsh\n220-weekly-log.zsh\n230-lefthook-overrides.zsh'
for identity in Darwin:Personal Darwin:Work Linux:Personal Linux:Work Linux:NAS:qts; do
  parts=("${(@s/:/)identity}")
  yd config local.os "$parts[1]"
  yd config local.class "$parts[2]"
  yd config local.distro "${parts[3]:-test}"
  # Remove only fixture-generated links before switching identity.
  for link in "$scratch/identity/checks.d/"*.zsh(@); do
    rm "$link"
  done
  yd alt > "$scratch/yadm-output" 2>&1
  if [[ $parts[1] == Darwin ]]; then
    expected=$'010-tmux-local-network.zsh\n'"$common"
    if [[ $parts[2] == Work ]]; then
      expected+=$'\n100-desktop.zsh\n110-peripherals.zsh'
    fi
  else
    expected="$common"$'\n070-glibc-compat.zsh'
  fi
  [[ $parts[2] != Work ]] || expected+=$'\n'"$work"
  expect_run 0 "$expected"
  print -r -- "PASS: $identity selection"
done
print 'PASS: discovery, ordering, isolation, warnings, and failure aggregation'

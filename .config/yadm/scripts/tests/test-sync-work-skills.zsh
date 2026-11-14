#!/usr/bin/env zsh

# Isolated updater fixtures: no network calls or changes to installed skills.
set -eu
scripts=${0:A:h:h}
source "$scripts/tests/lib/test-helpers.zsh"
test_sandbox jq rsync
trap test_cleanup EXIT
sandbox=$TEST_SANDBOX
fail() { print -ru2 -- "FAIL: $*"; exit 1; }

mkdir -p "$HOME/.agents/skills.work/esquery"
export FIXTURE_CLASS=Work FIXTURE_MODE=noop
export FIXTURE_TRACE="$sandbox/trace"
lock="$HOME/.agents/.skill-lock.json"
shared="$HOME/.agents/skills/esquery"
work="$HOME/.agents/skills.work/esquery"
print original > "$work/SKILL.md"
print stale > "$work/removed.md"
print '{"version":3,"skills":{"esquery":{"skillFolderHash":"original"},"grilling":{"skillFolderHash":"personal"}}}' > "$lock"
cp "$lock" "$sandbox/lock-before"

test_stub yadm <<'EOF'
#!/usr/bin/env zsh
print -r -- "$FIXTURE_CLASS"
EOF
test_stub npx <<'EOF'
#!/usr/bin/env zsh
set -eu
print -r -- "$*" >> "$FIXTURE_TRACE"
shared="$HOME/.agents/skills/esquery"
if [[ "$FIXTURE_CLASS" != Work ]]; then
  [[ "$*" != *esquery* && ! -e "$shared" && ! -L "$shared" ]] || exit 91
  exit 0
fi
[[ -L "$shared" && $(<"$shared/SKILL.md") == original ]] || exit 92
case "$FIXTURE_MODE" in
  noop) ;;
  failure) exit 7 ;;
  update|partial-failure)
    # Match the updater replacing the canonical symlink with a new snapshot.
    unlink "$shared"
    mkdir "$shared"
    print updated > "$shared/SKILL.md"
    jq '.skills.esquery.skillFolderHash = "updated"' "$HOME/.agents/.skill-lock.json" > "$HOME/new-lock"
    mv "$HOME/new-lock" "$HOME/.agents/.skill-lock.json"
    [[ "$FIXTURE_MODE" != partial-failure ]] || exit 8
    ;;
esac
EOF

mkdir -p "$HOME/.agents/skills/orbit-cli"
print local-cli > "$HOME/.agents/skills/orbit-cli/SKILL.md"
test_expect_status 'initial skill relocation' 0 zsh -df "$scripts/sync-work-skills.zsh"
[[ ! -e "$HOME/.agents/skills/orbit-cli" && ! -L "$HOME/.agents/skills/orbit-cli" ]] || fail 'orbit-cli left in shared discovery directory'
[[ $(<"$HOME/.agents/skills.work/orbit-cli/SKILL.md") == local-cli ]] || fail 'orbit-cli snapshot not relocated'

run_sync() {
  test_expect_status "sync $FIXTURE_CLASS/$FIXTURE_MODE" "$1" zsh -df "$scripts/sync-work-skills.zsh" --update
  [[ ! -e "$shared" && ! -L "$shared" ]] || fail 'work skill left in shared discovery directory'
}

run_sync 0
run_sync 0
cmp -s "$lock" "$sandbox/lock-before" || fail 'unchanged update rewrote lockfile'
[[ $(<"$work/SKILL.md") == original ]] || fail 'unchanged snapshot modified'

export FIXTURE_MODE=failure
run_sync 7
cmp -s "$lock" "$sandbox/lock-before" || fail 'failed update rewrote lockfile'

export FIXTURE_CLASS=Personal
run_sync 0
export FIXTURE_CLASS=Work

for mode in update partial-failure; do
  export FIXTURE_MODE=$mode
  print original > "$work/SKILL.md"
  print stale > "$work/removed.md"
  if [[ $mode == update ]]; then
    run_sync 0
  else
    run_sync 8
  fi
  [[ $(<"$work/SKILL.md") == updated && ! -e "$work/removed.md" ]] || fail 'updated snapshot not synced back'
  [[ $(jq -r '.skills.esquery.skillFolderHash' "$lock") == updated ]] || fail 'real lockfile update lost'
done

print 'PASS: no-op updates, work isolation, real updates, and failure cleanup'

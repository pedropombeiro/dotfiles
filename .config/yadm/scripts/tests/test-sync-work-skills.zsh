#!/usr/bin/env zsh

# Isolated updater fixtures: no network calls or changes to installed skills.
set -eu
scripts=${0:A:h:h}
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/sync-work-skills-test.XXXXXXXX")
trap 'rm -rf -- "$sandbox"' EXIT
fail() { print -ru2 -- "FAIL: $*"; exit 1; }

mkdir -p "$sandbox/bin" "$sandbox/home/.agents/skills.work/esquery"
export HOME="$sandbox/home" PATH="$sandbox/bin:$PATH"
export FIXTURE_CLASS=Work FIXTURE_MODE=noop
export FIXTURE_TRACE="$sandbox/trace"
lock="$HOME/.agents/.skill-lock.json"
shared="$HOME/.agents/skills/esquery"
work="$HOME/.agents/skills.work/esquery"
print original > "$work/SKILL.md"
print stale > "$work/removed.md"
print '{"version":3,"skills":{"esquery":{"skillFolderHash":"original"},"grilling":{"skillFolderHash":"personal"}}}' > "$lock"
cp "$lock" "$sandbox/lock-before"

cat > "$sandbox/bin/yadm" <<'EOF'
#!/usr/bin/env zsh
print -r -- "$FIXTURE_CLASS"
EOF
cat > "$sandbox/bin/npx" <<'EOF'
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
chmod +x "$sandbox/bin/yadm" "$sandbox/bin/npx"

run_sync() {
  local expected=$1 rc=0
  zsh "$scripts/sync-work-skills.zsh" --update > "$sandbox/output" 2>&1 || rc=$?
  [[ $rc == $expected ]] || { cat "$sandbox/output"; fail "expected exit $expected, got $rc"; }
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

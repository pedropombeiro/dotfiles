#!/usr/bin/env zsh

emulate -LR zsh
setopt err_exit

scripts=${0:A:h:h}
source "$scripts/tests/lib/test-helpers.zsh"
test_sandbox grep
trap test_cleanup EXIT

check="$scripts/checks.d/040-agent-doc-links.zsh"
docs="$HOME/.agents/docs"
mkdir -p "$docs" "$HOME/.config/opencode/local-plugins/tui/demo"

# A doc that links to a file, to an anchor, to a YADM alternate, and to a
# plugin README that only exists as an alternate.
cat > "$docs/doc.md" <<'MARKDOWN'
# Doc

- [plain](target.md)
- [plain anchor](target.md#a-heading)
- [gated](gated.md)
- [gated anchor](gated.md#gated-heading)
- [plugin](../../.config/opencode/local-plugins/tui/demo/README.md)
- [missing](missing.md)
- [missing anchor](target.md#no-such-heading)
MARKDOWN

cat > "$docs/target.md" <<'MARKDOWN'
# Target

## A Heading
MARKDOWN

cat > "$docs/gated.md##class.Work,extension.md" <<'MARKDOWN'
# Gated

## Gated Heading
MARKDOWN

cat > "$HOME/.config/opencode/local-plugins/tui/demo/README.md##class.Work,extension.md" <<'MARKDOWN'
# Demo
MARKDOWN

test_expect_status 'agent doc links' 0 zsh -df "$check"

output="$TEST_SANDBOX/output"
grep -q 'doc.md -> missing.md (no such file)' "$output" || test_fail 'missing file not reported'
grep -q 'doc.md -> target.md#no-such-heading (no such heading)' "$output" || test_fail 'missing heading not reported'
[[ $(grep -c 'WARN' "$output") -eq 2 ]] || {
  cat "$output" >&2
  test_fail 'unexpected number of warnings'
}

print 'PASS: agent doc links resolve plain files, anchors, and YADM alternates'

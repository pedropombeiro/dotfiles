#!/usr/bin/env zsh

emulate -LR zsh
setopt err_exit

scripts=${0:A:h:h}
filter="$scripts/lib/validate-jsonc.jq"
source "$scripts/tests/lib/test-helpers.zsh"
test_sandbox jq
trap test_cleanup EXIT

cat > "$TEST_SANDBOX/valid.jsonc" <<'JSONC'
// Managed configuration
{
  "url": "https://example.org/path//value",
  "comment": "/* keep this */ and // this",
  "escaped": "a quote: \" and a backslash: \\",
  "delimiters": ",] ,}",
  /* A multiline
     comment */
  "items": [1, 2, /* trailing comma */],
  "nested": {"enabled": true,},
}
JSONC
test_expect_status 'comments, strings, and trailing commas' 0 jq -Rs -f "$filter" "$TEST_SANDBOX/valid.jsonc"
if jq empty "$TEST_SANDBOX/valid.jsonc" >/dev/null 2>&1; then
  test_fail 'strict JSON unexpectedly accepted JSONC'
fi

for invalid in \
  '{"missing": }' \
  '{"comma": [1,,2]}' \
  '{"quote": "unterminated}' \
  '{"escape": "\q"}' \
  '{"value": 1 /* unclosed}' \
  '{"value": 1} extra' \
  '{"value": undefined}' \
  '{"value": 1 2}' \
  ''; do
  print -r -- "$invalid" > "$TEST_SANDBOX/invalid.jsonc"
  test_expect_status "reject malformed input: $invalid" 5 jq -Rs -f "$filter" "$TEST_SANDBOX/invalid.jsonc"
done

print 'PASS: JSONC validation accepts supported syntax and rejects malformed input'

# Exercise the validator's dispatch, not just the JSONC filter in isolation.
mkdir -p "$HOME/.config/opencode"
git -C "$HOME" init -q
git -C "$HOME" config local.class NAS
git -C "$HOME" config local.os Linux
git -C "$HOME" config local.distro qts
print '{}' > "$HOME/.config/opencode/opencode.json##template"
print '{}' > "$HOME/ordinary.json##template"
git -C "$HOME" add .config/opencode/opencode.json##template ordinary.json##template
test_stub yadm <<'SH'
#!/bin/sh
printf '%s\n' "$HOME/.git"
SH
cp "$TEST_SANDBOX/valid.jsonc" "$HOME/.config/opencode/opencode.json"
print '{}' > "$HOME/ordinary.json"
validator="$scripts/validators/check-rendered-alts.zsh"
test_expect_status 'OpenCode JSONC accepted by rendered validator' 0 zsh -df "$validator"
cp "$TEST_SANDBOX/valid.jsonc" "$HOME/ordinary.json"
test_expect_status 'ordinary JSON remains strict' 1 zsh -df "$validator"
grep -q 'invalid JSON: ordinary.json' "$TEST_SANDBOX/output" || test_fail 'missing strict JSON diagnostic'
print '{}' > "$HOME/ordinary.json"
print '{"missing": }' > "$HOME/.config/opencode/opencode.json"
test_expect_status 'malformed OpenCode JSONC rejected' 1 zsh -df "$validator"
grep -q 'invalid JSONC: .config/opencode/opencode.json' "$TEST_SANDBOX/output" || test_fail 'missing JSONC diagnostic'
print 'PASS: rendered validator selects JSONC only for OpenCode server configuration'

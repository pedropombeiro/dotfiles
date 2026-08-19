# Tool Usage

Workarounds for observed tool-layer failures. These are mitigations, not diagnoses — prefer the
mitigation even when the underlying cause is unconfirmed.

## Large file writes truncate

**Symptom:** a `write` call fails with a JSON parse error whose echoed payload is cut off
mid-object, e.g.:

```
Invalid input for tool write: JSON parsing failed:
Text: {"filePath": "/path/to/file.md".
Error message: JSON Parse error: Expected '}'
```

The `content` key and closing brace are missing. The arguments were truncated in transit, so
retrying the identical call usually fails again — though it is flaky rather than deterministic,
and an occasional retry does get through.

**Mitigation:** load the `write-large-file` skill and follow it. It is the canonical procedure —
chunked `cat >` / `cat >>` with quoted heredocs, split at section boundaries, verified with `wc -l`.
Bypassing the `write` tool entirely avoids the truncation path rather than working around it.

Fall back to the skeleton-plus-`edit` approach only when heredocs are impractical (content contains
arbitrary delimiters, or you are editing an existing file rather than creating one): `write` a
skeleton of headings with placeholder comments (`<!-- S1 -->`), then replace each placeholder with a
separate `edit` call.

**Caveats:**

- The size threshold is unverified. The skill says ~150 lines; two observed failures were at
  ~180 lines, with successes well below that. Treat ~100 lines as the conservative trigger point.
- Content shape may matter as much as length. Both observed failures were markdown containing
  tables, backticks, and many inline links.
- This is a harness-level issue, not a property of any particular project. Keep the mitigation in
  the global `write-large-file` skill — do not copy it into project skills, prompts, or specs,
  especially in repos intended to be forked, where the fork's harness may not have the problem.

## `sed -i` silently destroys non-ASCII characters

**Symptom:** a `sed -i '' 's/old/new/g'` rename appears to succeed, but unrelated lines show up in
the diff with no visible change. The lines look byte-identical in terminal output and in `read`.

Observed in `~/.config/yazi/init.lua`, where a variable rename stripped the Nerd Font glyphs from
label strings — `search_label = "\uf002 search"` became `search_label = " search"`. The diff showed
the lines as modified, but both versions rendered identically, so the damage was invisible.

**Mitigation:** use the `edit` tool for renames, even repetitive ones. Use `edit` with
`replaceAll: true` for a whole-file rename rather than reaching for `sed`.

This matters well beyond one config file: Nerd Font glyphs, box-drawing characters, emoji, and
accented text are common in prompts, status lines, themes, and docs across these dotfiles.

**Detection:** `read` and plain `diff` are not sufficient — compare bytes.

```bash
# Confirm a suspicious line survived intact
sed -n '186p' init.lua | hexdump -C
yadm show HEAD:.config/yazi/init.lua | sed -n '186p' | hexdump -C
```

Before committing any mechanical rewrite of a file containing non-ASCII characters, check that the
diff contains only intended hunks:

```bash
yadm diff <file> | grep -E "^[-+]" | grep -v <expected-pattern>
```

**Recovery:** restore the affected lines from `HEAD` rather than retyping the glyphs, which risks
substituting a similar-looking codepoint:

```bash
yadm show HEAD:<path> | sed -n '<start>,<end>p'   # inspect
# then splice those exact lines back over the damaged range
```

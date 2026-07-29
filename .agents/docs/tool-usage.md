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

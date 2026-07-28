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

**Mitigation:** for files over roughly 100 lines, do not write the whole file in one call.

1. `write` a skeleton containing the final headings plus a placeholder comment per section, e.g.
   `<!-- S1 -->`, `<!-- S2 -->`.
2. Fill each section with a separate `edit` call, replacing its placeholder.
3. Verify the result (`rg -n '^#'` for structure, `awk 'length > N'` for line-length limits).

**Caveats:**

- The size threshold is unverified. ~100 lines is a conservative guess based on two failures at
  ~180 lines and successes well below that.
- Content shape may matter as much as length. Both observed failures were markdown containing
  tables, backticks, and many inline links.
- This is a harness-level issue, not a property of any particular project. Do not encode the
  workaround in project skills, prompts, or specs — especially in repos intended to be forked,
  where the fork's harness may not have the problem.

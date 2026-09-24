# Limitations Reference

## `question` Tool in Non-Interactive Runs

If the agent calls the `question` tool during `opencode run`, the process can hang waiting for input.

Workaround:

```bash
timeout 30 opencode run --standalone 'your prompt' || echo "Timed out: agent may have tried to ask a question"
```

On macOS with coreutils:

```bash
gtimeout 30 opencode run --standalone 'your prompt' || echo "Timed out: agent may have tried to ask a question"
```

## Permissions Depend on `opencode.json`

The behavior of shell-invoking prompts depends on your actual shell permission configuration (`bash` in V1-style config, `shell` in V2 `permissions`).

```bash
opencode debug config | jq '.[].info.permissions'
```

Rules that resolve to `ask` are rejected automatically in `opencode run`. The global config
asks before reading files under `~/.config/opencode/`, so a test prompt that reads OpenCode's
own config or skills through that path fails unless you pass `--auto`.

## Config File Locations

`opencode` merges config from lowest to highest precedence:

1. `~/.config/opencode/opencode.json` or `opencode.jsonc`
2. `opencode.json(c)` in the working directory and its parent directories
3. `.opencode/opencode.json(c)` in those same directories
4. Inline config from `OPENCODE_CONFIG_CONTENT`

List the sources that apply to a directory, with their normalized content:

```bash
opencode debug config | jq -r '.[].path'
```

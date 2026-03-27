# Limitations Reference

## `question` Tool in Non-Interactive Runs

If the agent calls the `question` tool during `opencode run`, the process can hang waiting for input.

Workaround:

```bash
timeout 30 opencode run 'your prompt' || echo "Timed out — agent may have tried to ask a question"
```

On macOS with coreutils:

```bash
gtimeout 30 opencode run 'your prompt' || echo "Timed out — agent may have tried to ask a question"
```

## Permissions Depend on `opencode.json`

The behavior of shell-invoking prompts depends on your actual `bash` permission configuration.

```bash
cat ~/.config/opencode/opencode.json | python3 -m json.tool
```

## Config File Locations

`opencode` checks multiple config files:

1. `~/.config/opencode/opencode.json`
2. `~/.config/opencode/opencode.jsonc`
3. `~/.opencode/opencode.json`
4. `<workdir>/opencode.json`

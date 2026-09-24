# run-in-tmux-pane

Run commands in a temporary tmux pane with the user's interactive zsh environment
and return captured output to the agent.

## Requirements

- macOS or Linux
- tmux, with the agent session running inside it
- zsh

## Installation

Link the bundled helper onto your `PATH`:

```bash
ln -s /path/to/skills/run-in-tmux-pane/scripts/run-in-tmux-pane ~/.local/bin/run-in-tmux-pane
```

## Agent workflow

Read [SKILL.md](SKILL.md) for execution decisions, configuration, output behavior,
and timeout budgets. See [the usage reference](references/USAGE.md) for quoting
and command examples.

## License

MIT

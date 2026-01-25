# Shell Configuration

Zsh configuration with modular structure and zinit plugins.

## Structure

```
~/.shellrc/
├── zshrc.d/
│   ├── configs/
│   │   ├── pre/          # Early-load (zinit, mise, brew)
│   │   ├── [main]        # Core configs
│   │   └── post/         # Late-load (keybindings, fzf)
│   └── functions/        # Autoloaded shell functions
└── rc.d/                 # Shared bash/zsh configs
```

## Key Files

- `~/.zshrc.shared` - Main zsh entry point
- `~/.shellrc/zshrc.d/configs/zinit.zsh` - Plugin manager setup
- `~/.shellrc/zshrc.d/configs/post/keybindings.zsh` - Key mappings

## Loading Order

1. `pre/` configs load first (zinit, runtime managers)
2. Main configs in `configs/` directory
3. `post/` configs load last (keybindings, fzf integration)

## Alternate Files

Use platform-specific suffixes:

- `##distro.qts` - QNAP QTS
- `##os.Darwin` - macOS
- `##os.Linux` - Generic Linux
- `##class.Work` - Work-specific configs

## Adding Functions

Create files in `~/.shellrc/zshrc.d/functions/`:

- One function per file
- Filename = function name
- No file extension needed
- Functions are autoloaded on first use

## Key Integrations

| Tool          | Purpose                        |
| ------------- | ------------------------------ |
| zinit         | Plugin manager (turbo loading) |
| mise          | Runtime/tool version manager   |
| fzf           | Fuzzy finder                   |
| zoxide        | Smart directory jumping        |
| powerlevel10k | Prompt theme                   |

## Guidelines

- Keep functions small and focused
- Use autoloaded functions for infrequently-used commands
- Prefer zinit ice modifiers for plugin configuration
- Document environment variables in comments
- Source `~/.zshrc` to test changes

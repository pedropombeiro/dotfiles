# Neovim Configuration

## Configuration Location

**Primary config directory:** `~/.config/nvim/`

## Structure

- **`init.lua`** - Main entry point that bootstraps the configuration
- **`lua/core/`** - Core Neovim settings (options, keymaps, autocmds, etc.)
- **`lua/plugins/`** - Individual plugin configurations
- **`lua/plugins/lsp/`** - LSP-specific plugin configurations
- **`lua/config/`** - Additional configuration modules
- **`ftplugin/`** - Filetype-specific settings
- **`after/`** - Files loaded after default runtime files
- **`snippets/`** - Custom snippets

## Plugin Manager

**lazy.nvim** is used for plugin management.

- **Plugin specs:** `lua/plugins/*.lua` and `lua/plugins/lsp/*.lua`
- **Data directory:** `~/.local/share/nvim/lazy/` (where plugins are installed)

### Adding Plugins

Create or edit files in `lua/plugins/` or `lua/plugins/lsp/`. Each file should return a plugin spec table:

```lua
-- <plugin-name> (https://github.com/<author>/<plugin-name>)
--   <Repo description>

return {
  "author/plugin-name",
  opts = {},
}
```

### Managing Plugins

- `:Lazy` - Open lazy.nvim UI
- `:Lazy sync` - Install/update/clean plugins
- `:Lazy update` - Update plugins

## Common Operations

- **Edit config:** Modify files in `~/.config/nvim/lua/`
- **Edit plugin config:** Add/edit files in `~/.config/nvim/lua/plugins/`
- **Edit core settings:** Modify files in `~/.config/nvim/lua/core/`
- **Check plugin status:** Run `:Lazy` in Neovim

## YADM Integration

The configuration includes special handling for YADM (dotfile manager) tracked files. Three plugins coordinate to provide seamless YADM support:

### Components

1. **gitsigns-yadm.nvim** (`lua/plugins/gitsigns.lua`)

   - Detects when a buffer is tracked by YADM (not a regular git repo)
   - Sets `vim.b.yadm_tracked = true` on YADM-tracked buffers via `on_yadm_attach`
   - Passes YADM context to gitsigns so hunks/blame work correctly

2. **snacks.nvim** (`lua/plugins/snacks.lua`)

   - Helper functions detect YADM context:
     - `is_yadm_repo(dir)` - Returns true if in `~` or `~/.config`
     - `yadm_opts()` - Returns git args: `--git-dir ~/.local/share/yadm/repo.git --work-tree ~`
     - `git_opts()` - Returns YADM opts when appropriate, empty otherwise
   - Picker operations (git grep, git status, etc.) automatically use YADM when in home/config dirs
   - LazyGit opens with YADM args when appropriate
   - Explorer git actions (`<leader>ga`, `<leader>gr`) use `yadm` command in YADM repos

3. **lualine.nvim** (`lua/plugins/lualine.lua`)
   - Shows `⊛ YADM` indicator in statusline when `vim.b.yadm_tracked == true`
   - Appears in `lualine_b` section alongside git branch

### Keybindings

- `<leader>fgy` - YADM grep (search dotfiles content)
- `<leader>fgs` - Git/YADM status (auto-detects context)
- `<leader>fgc` - Git/YADM log (auto-detects context)
- `<leader>/` - Git/YADM grep (auto-detects context)
- `<leader>tg` - LazyGit (opens with YADM args when appropriate)

### How Detection Works

When editing a file:

1. `gitsigns-yadm.nvim` checks if file is YADM-tracked (not in a git repo but tracked by YADM)
2. If YADM-tracked, sets `vim.b.yadm_tracked = true`
3. Lualine checks this variable to show the YADM indicator
4. Snacks picker operations check `is_yadm_repo(cwd)` to determine which git args to use

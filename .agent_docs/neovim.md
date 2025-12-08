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

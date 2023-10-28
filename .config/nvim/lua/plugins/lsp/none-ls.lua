-- none-ls.nvim (https://github.com/nvimtools/none-ls.nvim)
--  Use Neovim as a language server to inject LSP diagnostics, code actions, and more via Lua.

return {
  'nvimtools/none-ls.nvim',
  dependencies = 'nvim-lua/plenary.nvim',
  lazy = true,
  config = function()
    local null_ls_status_ok, null_ls = pcall(require, 'null-ls')
    if not null_ls_status_ok then
      return
    end

    -- stylua: ignore start
    local builtins     = null_ls.builtins
    local code_actions = builtins.code_actions
    local completion   = builtins.completion
    local diagnostics  = builtins.diagnostics
    local hover        = builtins.hover
    local conditional  = function(fn)
      local utils = require('null-ls.utils').make_conditional_utils()
      return fn(utils)
    end
    -- stylua: ignore end

    local sources = {
      code_actions.gitsigns,
      code_actions.shellcheck,

      completion.spell,

      diagnostics.checkmake,
      -- setting eslint_d only if we have a ".eslintrc.js" file in the project
      diagnostics.eslint_d.with({
        condition = function(utils)
          return utils.root_has_file({ '.eslintrc.js' })
        end,
      }),
      diagnostics.golangci_lint,
      diagnostics.hadolint,
      diagnostics.jsonlint,
      diagnostics.luacheck.with({
        extra_args = { '--globals', 'vim' },
      }),
      diagnostics.markdownlint,
      --diagnostics.semgrep,
      diagnostics.shellcheck,
      diagnostics.vale,
      diagnostics.yamllint,
      diagnostics.zsh,

      hover.dictionary,
    }
  end,
}

-- none-ls.nvim (https://github.com/nvimtools/none-ls.nvim)
--  Use Neovim as a language server to inject LSP diagnostics, code actions, and more via Lua.

return {
  'nvimtools/none-ls.nvim',
  event = { 'BufReadPost', 'BufNewFile', 'BufWritePre' },
  dependencies = { 'mason.nvim', 'nvim-lua/plenary.nvim' },
  optional = true,
  opts = function()
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
      diagnostics.zsh,

      hover.dictionary,
    }
    if vim.fn.executable('yamllint') == 1 then
      table.insert(sources, diagnostics.yamllint)
    end

    return { sources = sources }
  end,
}

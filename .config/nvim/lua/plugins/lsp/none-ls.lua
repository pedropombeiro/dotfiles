-- none-ls.nvim (https://github.com/nvimtools/none-ls.nvim)
--  Use Neovim as a language server to inject LSP diagnostics, code actions, and more via Lua.

return {
  {
    "nvimtools/none-ls.nvim",
    event = { "BufReadPost", "BufNewFile", "BufWritePre" },
    dependencies = { "mason.nvim" },
    optional = true,
    opts = function()
      local null_ls_status_ok, null_ls = pcall(require, "null-ls")
      if not null_ls_status_ok then return end

      -- stylua: ignore start
      local builtins     = null_ls.builtins
      local code_actions = builtins.code_actions
      local completion   = builtins.completion
      local diagnostics  = builtins.diagnostics
      local hover        = builtins.hover
      -- stylua: ignore end

      local sources = {
        code_actions.gomodifytags, -- Go tool to modify struct field tags
        code_actions.impl, -- impl generates method stubs for implementing an interface.
        code_actions.gitsigns, -- Injects code actions for Git operations at the current cursor position (stage / preview / reset hunks, blame, etc.).

        completion.spell.with({
          filetypes = { "json", "yaml", "markdown" },
        }),

        diagnostics.checkmake, -- make linter
        diagnostics.gitlint, -- Linter for Git commit messages
        diagnostics.golangci_lint, -- A Go linter aggregator
        diagnostics.hadolint, -- A smarter Dockerfile linter that helps you build best practice Docker images
        diagnostics.mypy.with({
          filetypes = { "python" },
        }),
        --diagnostics.semgrep,
        diagnostics.vale,
        diagnostics.zsh, -- Uses zsh's own -n option to evaluate, but not execute, zsh scripts

        hover.dictionary, -- Shows the first available definition for the current word under the cursor
      }
      if vim.fn.executable("yamllint") == 1 then table.insert(sources, diagnostics.yamllint) end

      return { sources = sources }
    end,
  },
  { "nvim-lua/plenary.nvim", lazy = true },
}

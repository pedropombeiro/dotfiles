-- null-ls.nvim (https://github.com/jose-elias-alvarez/null-ls.nvim)
--  Use Neovim as a language server to inject LSP diagnostics, code actions, and more via Lua.

local null_ls      = require("null-ls")
local builtins     = null_ls.builtins
local code_actions = builtins.code_actions
local completion   = builtins.completion
local diagnostics  = builtins.diagnostics
local formatting   = builtins.formatting
local hover        = builtins.hover

local sources = {
  code_actions.gitsigns,
  code_actions.shellcheck,

  completion.spell,

  diagnostics.checkmake,
  diagnostics.golangci_lint,
  diagnostics.hadolint,
  diagnostics.jsonlint,
  --diagnostics.semgrep,
  diagnostics.shellcheck,
  diagnostics.yamllint,
  diagnostics.zsh,

  formatting.fixjson,
  formatting.markdown_toc,
  formatting.markdownlint,
  formatting.nginx_beautifier,
  formatting.pg_format,
  formatting.rubocop,
  formatting.shfmt,
  formatting.sql_formatter,
  formatting.taplo,
  formatting.yamlfmt,

  hover.printenv,
}

null_ls.setup({
  sources = sources
})

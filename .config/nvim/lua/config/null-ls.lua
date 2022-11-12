-- null-ls.nvim (https://github.com/jose-elias-alvarez/null-ls.nvim)
--  Use Neovim as a language server to inject LSP diagnostics, code actions, and more via Lua.

local null_ls = require("null-ls")

local sources = {
  null_ls.builtins.code_actions.gitsigns,
  null_ls.builtins.code_actions.shellcheck,

  null_ls.builtins.completion.spell,

  null_ls.builtins.diagnostics.checkmake,
  null_ls.builtins.diagnostics.golangci_lint,
  null_ls.builtins.diagnostics.hadolint,
  null_ls.builtins.diagnostics.jsonlint,
  null_ls.builtins.diagnostics.markdownlint,
  --null_ls.builtins.diagnostics.semgrep,
  null_ls.builtins.diagnostics.shellcheck,
  null_ls.builtins.diagnostics.yamllint,
  null_ls.builtins.diagnostics.zsh,

  null_ls.builtins.formatting.fixjson,
  null_ls.builtins.formatting.markdown_toc,
  null_ls.builtins.formatting.markdownlint,
  null_ls.builtins.formatting.nginx_beautifier,
  null_ls.builtins.formatting.pg_format,
  null_ls.builtins.formatting.rubocop,
  null_ls.builtins.formatting.shfmt,
  null_ls.builtins.formatting.sql_formatter,
  null_ls.builtins.formatting.taplo,
  null_ls.builtins.formatting.yamlfmt,

  null_ls.builtins.hover.printenv,
}
if not vim.g.started_by_firenvim then
  -- do not enable vale in the context of firenvim, since there will be no config file
  table.insert(sources, null_ls.builtins.diagnostics.vale)
end

null_ls.setup({
  sources = sources
})

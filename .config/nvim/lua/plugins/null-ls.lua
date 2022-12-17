-- null-ls.nvim (https://github.com/jose-elias-alvarez/null-ls.nvim)
--  Use Neovim as a language server to inject LSP diagnostics, code actions, and more via Lua.

local null_ls_status_ok, null_ls = pcall(require, "null-ls")
if not null_ls_status_ok then
  return
end

local builtins     = null_ls.builtins
local code_actions = builtins.code_actions
local completion   = builtins.completion
local diagnostics  = builtins.diagnostics
local formatting   = builtins.formatting
local hover        = builtins.hover
local conditional  = function(fn)
  local utils = require("null-ls.utils").make_conditional_utils()
  return fn(utils)
end

local sources = {
  code_actions.gitsigns,
  code_actions.shellcheck,

  completion.spell,

  diagnostics.checkmake,
  -- setting eslint_d only if we have a ".eslintrc.js" file in the project
  diagnostics.eslint_d.with({
    condition = function(utils)
      return utils.root_has_file({ ".eslintrc.js" })
    end,
  }),
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
  formatting.prettier,
  formatting.shfmt,
  formatting.sql_formatter,
  formatting.taplo,
  formatting.yamlfmt,

  hover.printenv,
}

null_ls.setup({
  debug = false,

  sources = sources,

  -- Here we set a conditional to call the rubocop formatter.
  -- If we have a Gemfile in the project, we call "bundle exec rubocop", if not we only call "rubocop".
  conditional(function(utils)
    return utils.root_has_file("Gemfile")
        and formatting.rubocop.with({
          command = "bundle",
          args = vim.list_extend({ "exec", "rubocop" }, formatting.rubocop._opts.args)
        })
        or formatting.rubocop
  end),

  -- Same as above, but with diagnostics.rubocop to make sure we use the proper rubocop version for the project
  conditional(function(utils)
    return utils.root_has_file("Gemfile")
        and diagnostics.rubocop.with({
          command = "bundle",
          args = vim.list_extend({ "exec", "rubocop" }, diagnostics.rubocop._opts.args)
        })
        or diagnostics.rubocop
  end),
})

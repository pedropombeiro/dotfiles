" -- null-ls.nvim (https://github.com/jose-elias-alvarez/null-ls.nvim)
if has("nvim")
  lua << EOF
  local null_ls = require("null-ls")

  null_ls.setup({
    sources = {
      null_ls.builtins.code_actions.gitsigns,
      null_ls.builtins.code_actions.shellcheck,
      null_ls.builtins.completion.spell,
      null_ls.builtins.diagnostics.checkmake,
      null_ls.builtins.diagnostics.yamllint,
      null_ls.builtins.diagnostics.zsh,
      null_ls.builtins.formatting.markdown_toc,
      null_ls.builtins.formatting.markdownlint,
      null_ls.builtins.formatting.nginx_beautifier,
      null_ls.builtins.formatting.pg_format,
      null_ls.builtins.formatting.rubocop,
      null_ls.builtins.formatting.shfmt,
      null_ls.builtins.formatting.stylua,
      null_ls.builtins.formatting.taplo,
      null_ls.builtins.formatting.yamlfmt,
      null_ls.builtins.hover.printenv,
    },
  })
EOF
endif

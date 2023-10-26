-- conform.nvim (https://github.com/stevearc/conform.nvim)
-- Lightweight yet powerful formatter plugin for Neovim

return {
  'stevearc/conform.nvim',
  dependencies = { 'mason.nvim' },
  lazy = true,
  event = { 'BufWritePre' },
  cmd = { 'ConformInfo' },
  keys = {
    {
      '<leader>lf',
      function()
        require('conform').format({ async = true, lsp_fallback = true })
      end,
      mode = { 'n' },
      desc = 'Format buffer',
    },
    {
      '<leader>lf',
      function()
        local range = {
          start = vim.api.nvim_buf_get_mark(0, '<'),
          ['end'] = vim.api.nvim_buf_get_mark(0, '>'),
        }

        require('conform').format({ async = true, lsp_fallback = true, range = range })
      end,
      mode = { 'v' },
      desc = 'Format selection',
    },
  },
  opts = {
    -- stylua: ignore
    formatters_by_ft = {
      javascript      = { 'prettier' },
      typescript      = { 'prettier' },
      javascriptreact = { 'prettier' },
      typescriptreact = { 'prettier' },
      svelte          = { 'prettier' },
      css             = { 'prettier' },
      html            = { 'prettier' },
      json            = { { 'prettier', 'fixjson', 'jq' } },
      just            = { 'just' },
      yaml            = { { 'prettier', 'yamlfmt' } },
      markdown        = { 'markdown-toc', 'markdownlint' },
      graphql         = { 'prettier' },
      lua             = { 'stylua' },
      python          = { 'isort', 'black' },
      ruby            = { 'rubocop' },
      sh              = { 'shellcheck', 'shfmt' },
      zsh             = { 'shellcheck', 'shfmt' },
      sql             = { { 'pg_format', 'sql_formatter' } },
      toml            = { 'taplo' },
    },
    format_on_save = {
      lsp_fallback = true,
      async = false,
      timeout_ms = 2000,
    },
    -- Customize formatters
    formatters = {
      lua = {
        prepend_args = { '--verify' },
      },
    },
  },
}

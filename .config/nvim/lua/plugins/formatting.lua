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
    {
      ']of',
      function()
        vim.b.disable_autoformat = true
      end,
      desc = 'Disable autoformat-on-save',
    },
    {
      '[of',
      function()
        vim.b.disable_autoformat = false
      end,
      desc = 'Enable autoformat-on-save',
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
    format_on_save = function(bufnr)
      -- Disable with a global or buffer-local variable
      if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
        return
      end

      return {
        lsp_fallback = true,
        async = false,
        timeout_ms = 2000,
      }
    end,
    -- Customize formatters
    formatters = {
      lua = {
        prepend_args = { '--verify' },
      },
    },
  },
}

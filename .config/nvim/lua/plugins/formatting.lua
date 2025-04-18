-- conform.nvim (https://github.com/stevearc/conform.nvim)
-- Lightweight yet powerful formatter plugin for Neovim

return {
  "stevearc/conform.nvim",
  dependencies = { "mason.nvim" },
  lazy = true,
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  ---@module "lazy"
  ---@type LazyKeysSpec[]
  keys = {
    {
      "<leader>lf",
      function() require("conform").format({ async = true, lsp_fallback = true }) end,
      mode = { "n" },
      desc = "Format buffer",
    },
    {
      "<leader>lf",
      function() require("conform").format({ async = true, lsp_fallback = true }) end,
      mode = { "v" },
      desc = "Format selection",
    },
    {
      "<leader>lF",
      function() require("conform").format({ formatters = { "injected" } }) end,
      mode = { "n", "v" },
      desc = "Format injected langs",
    },
    {
      "]of",
      function() vim.b.disable_autoformat = true end,
      desc = "Disable autoformat-on-save",
    },
    {
      "[of",
      function() vim.b.disable_autoformat = false end,
      desc = "Enable autoformat-on-save",
    },
  },
  init = function() vim.g.disable_autoformat = true end,
  ---@type conform.setupOpts
  opts = {
    -- stylua: ignore
    formatters_by_ft = {
      css             = { "prettier" },
      eruby           = { "erb_format" },
      graphql         = { "prettier" },
      html            = { "prettier" },
      javascript      = { "prettier" },
      javascriptreact = { "prettier" },
      json            = { "prettier", "fixjson", "jq", stop_after_first = true },
      just            = { "just" },
      lua             = { "stylua" },
      markdown        = { "markdownlint-cli2" },
      nginx           = { "nginx" },
      python          = { "isort", "black" },
      ruby            = { "standardrb", "rubocop", stop_after_first = true },
      sh              = { "shellcheck", "shfmt" },
      sql             = { "pg_format", "sql_formatter", stop_after_first = true },
      svelte          = { "prettier" },
      toml            = { "taplo" },
      typescript      = { "prettier" },
      typescriptreact = { "prettier" },
      vue             = { "prettier" },
      yaml            = { "prettier", "yamlfmt", stop_after_first = true },
      zsh             = { "shellcheck", "shfmt" },
    },
    format_on_save = function(bufnr)
      -- Disable with a global or buffer-local variable
      if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then return end
      -- Disable autoformat for files in a certain path
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      if bufname:match("/node_modules/") or bufname:match("/vendor/") then return end

      return {
        lsp_fallback = false, -- LSP formatting on Ruby and Go files has proven to delete the first word of the changed line, so let's disable it
        timeout_ms = 3000,
        async = false, -- not recommended to change
        quiet = false, -- not recommended to change
      }
    end,
    -- Customize formatters
    formatters = {
      black = {
        prepend_args = { "--fast" },
      },
      lua = {
        prepend_args = { "--verify" },
      },
      nginx = {
        command = "nginxbeautifier",
        args = { "-s", "2", "-i", "-o", "$FILENAME" },
        stdin = false,
        require_cwd = false,
      },
    },
  },
}

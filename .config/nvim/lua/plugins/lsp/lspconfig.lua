-- nvim-lspconfig (https://github.com/neovim/nvim-lspconfig)
--  Quickstart configs for Nvim LSP

---@format disable-next
-- stylua: ignore
---@module "lazy"
---@type LazyKeysSpec[]
local keys = {
  { "[oH",         function() vim.lsp.inlay_hint.enable(true) end,  desc = "Enable inlay hints" },
  { "]oH",         function() vim.lsp.inlay_hint.enable(false) end, desc = "Disable inlay hints" },
  { "[d",          function() vim.diagnostic.goto_prev() end,       desc = "Previous LSP diagnostic" },
  { "]d",          function() vim.diagnostic.goto_next() end,       desc = "Next LSP diagnostic" },
  { "<f2>",        function() vim.lsp.buf.rename() end,             desc = "Rename symbol" },
  { "grn",         function() vim.lsp.buf.rename() end,             desc = "Rename symbol" },
  { "K",           function() vim.lsp.buf.hover() end,              desc = "Hover" },
  { "<leader>K",   function() vim.lsp.buf.signature_help() end,     desc = "Signature help" },
  { "<leader>lD",  function() vim.lsp.buf.declaration() end,        desc = "Go to declaration" },
  { "<leader>ly",  function() vim.lsp.buf.type_definition() end,    desc = "Go to type definition" },
  { "<leader>li",  function() vim.lsp.buf.implementation() end,     desc = "Go to implementation" },
  { "gri",         function() vim.lsp.buf.implementation() end,     desc = "Go to implementation" },
  { "grr",         function() vim.lsp.buf.references() end,         desc = "References" },
  { "<leader>lwa", function() vim.lsp.buf.add_workspace_folder() end, desc = "Add workspace folder" },
  {
    "<leader>lwl",
    function() Snacks.notify(vim.inspect(vim.lsp.buf.list_workspace_folders())) end,
    desc = "List workspace folders",
  },
}

return {
  {
    "b0o/SchemaStore.nvim", -- 🛍  JSON schemas for Neovim
    version = false, -- last release is way too old
    lazy = true,
  },
  {
    "neovim/nvim-lspconfig", -- Quickstart configs for Nvim LSP
    event = { "BufReadPre", "BufNewFile", "BufWritePre" },
    keys = keys,
    dependencies = {
      { "saghen/blink.cmp" },
      {
        --- uses Mason to ensure installation of user specified LSP servers and will tell nvim-lspconfig what command
        --- to use to launch those servers.
        "mason-org/mason-lspconfig.nvim",
        dependencies = "mason-org/mason.nvim",
        opts = {
          automatic_enable = false,
        },
      },
    },
    config = function()
      ---@type pmsp.neovim.Config
      local nvconfig = require("config")
      local border = nvconfig.ui.border
      local icons = nvconfig.ui.icons.diagnostics

      require("lspconfig.ui.windows").default_options.border = border

      local lsp_path = vim.fn.stdpath("config") .. "/after/lsp"
      local lsp_dir = vim.fn.globpath(lsp_path, "*.lua", false, true)
      for _, file in ipairs(lsp_dir) do
        local server = vim.fn.fnamemodify(file, ":t:r")
        vim.lsp.enable(server)
      end

      ---@type vim.diagnostic.Opts
      vim.diagnostic.config({
        folds = {
          enabled = true,
        },
        -- add any global capabilities here
        capabilities = {
          workspace = {
            fileOperations = {
              didRename = true,
              willRename = true,
            },
          },
        },
        severity_sort = true,
        float = { -- Show diagnostic source in float (e.g. goto_next, goto_prev)
          focusable = false,
          style = "minimal",
          border = border,
          source = false,
          header = "",
          suffix = "",
          prefix = "",
          format = function(value) return string.format("%s: [%s] %s", value.source, value.code, value.message) end,
        },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = icons.error .. " ",
            [vim.diagnostic.severity.WARN] = icons.warning .. " ",
            [vim.diagnostic.severity.HINT] = icons.hint .. " ",
            [vim.diagnostic.severity.INFO] = icons.info .. " ",
          },
          texthl = {
            [vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
            [vim.diagnostic.severity.WARN] = "DiagnosticSignWarning",
            [vim.diagnostic.severity.HINT] = "DiagnosticSignHint",
            [vim.diagnostic.severity.INFO] = "DiagnosticSignInfo",
          },
          numhl = {
            [vim.diagnostic.severity.ERROR] = "",
            [vim.diagnostic.severity.WARN] = "",
            [vim.diagnostic.severity.HINT] = "",
            [vim.diagnostic.severity.INFO] = "",
          },
        },
      })
    end,
  },
}

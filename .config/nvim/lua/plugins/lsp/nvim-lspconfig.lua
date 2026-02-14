-- nvim-lspconfig (https://github.com/neovim/nvim-lspconfig)
--  Quickstart configs for Nvim LSP

-- Track which capability-gated features have already been set up per (client, buffer)
-- to avoid duplicate keymaps/autocmds when dynamic registration fires.
---@type table<string, true>
local _capability_applied = {}

--- Enable capability-gated features for a (client, buffer) pair.
--- Safe to call multiple times — uses `_capability_applied` to skip work that was
--- already done (e.g. when called again after a `client/registerCapability` response).
---@param client vim.lsp.Client
---@param bufnr integer
local function apply_capability_features(client, bufnr)
  local wk = require("which-key")
  local key_prefix = client.id .. ":" .. bufnr

  -- Inlay hints: only enable toggle keymaps when the server supports them
  if client:supports_method("textDocument/inlayHint") and not _capability_applied[key_prefix .. ":inlayHint"] then
    _capability_applied[key_prefix .. ":inlayHint"] = true
    wk.add({
      buffer = bufnr,
      { "[oH", function() vim.lsp.inlay_hint.enable(true, { bufnr = bufnr }) end, desc = "Enable inlay hints" },
      { "]oH", function() vim.lsp.inlay_hint.enable(false, { bufnr = bufnr }) end, desc = "Disable inlay hints" },
    })
  end

  -- Format-on-save: register a buffer-local BufWritePre autocmd when the server
  -- supports textDocument/formatting.  This acts as a *fallback* — conform.nvim
  -- is the primary formatter and its format_on_save already runs on BufWritePre.
  -- The guard below ensures we only add LSP formatting for buffers where conform
  -- has no formatter configured, giving you the option to flip lsp_fallback later.
  if
    client:supports_method("textDocument/formatting")
    and not _capability_applied[key_prefix .. ":formatting"]
  then
    _capability_applied[key_prefix .. ":formatting"] = true
    vim.api.nvim_create_autocmd("BufWritePre", {
      group = vim.api.nvim_create_augroup("LspFormatOnSave_" .. bufnr, { clear = true }),
      buffer = bufnr,
      callback = function()
        -- Skip if autoformat is disabled (same flags conform.nvim checks)
        if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then return end
        -- Skip if conform has formatters for this filetype (let conform handle it)
        local ok, conform = pcall(require, "conform")
        if ok then
          local formatters = conform.list_formatters(bufnr)
          if #formatters > 0 then return end
        end
        -- No conform formatter — use LSP as fallback
        vim.lsp.buf.format({ bufnr = bufnr, id = client.id, timeout_ms = 3000 })
      end,
    })
  end
end

--- Set buffer-local keymaps when an LSP client attaches.
--- Following best practices from neovim.io/doc/user/lsp:
---   - All keymaps are buffer-local (set inside LspAttach)
---   - Capability checks gate features like inlay hints and formatting
---   - Format-on-save is registered per-buffer only when the server supports it
---   - Dynamic capability registration is handled so late-arriving capabilities
---     (e.g. inlay hints registered after initialize) are picked up automatically
---@param client vim.lsp.Client
---@param bufnr integer
local function on_attach(client, bufnr)
  local wk = require("which-key")

  wk.add({
    buffer = bufnr,
    -- Diagnostics (always available)
    { "[d", function() vim.diagnostic.goto_prev() end, desc = "Previous LSP diagnostic" },
    { "]d", function() vim.diagnostic.goto_next() end, desc = "Next LSP diagnostic" },
    -- Rename
    { "<f2>", function() vim.lsp.buf.rename() end, desc = "Rename symbol" },
    { "grn", function() vim.lsp.buf.rename() end, desc = "Rename symbol" },
    -- Hover / signature
    { "K", function() vim.lsp.buf.hover() end, desc = "Hover" },
    { "<leader>K", function() vim.lsp.buf.signature_help() end, desc = "Signature help" },
    -- Navigation
    { "<leader>lD", function() vim.lsp.buf.declaration() end, desc = "Go to declaration" },
    { "<leader>ly", function() vim.lsp.buf.type_definition() end, desc = "Go to type definition" },
    { "<leader>li", function() vim.lsp.buf.implementation() end, desc = "Go to implementation" },
    { "gri", function() vim.lsp.buf.implementation() end, desc = "Go to implementation" },
    { "grr", function() vim.lsp.buf.references() end, desc = "References" },
    -- Workspace folders
    { "<leader>lw", group = "Workspace folders" },
    { "<leader>lwa", function() vim.lsp.buf.add_workspace_folder() end, desc = "Add workspace folder" },
    {
      "<leader>lwl",
      function() Snacks.notify(vim.inspect(vim.lsp.buf.list_workspace_folders())) end,
      desc = "List workspace folders",
    },
  })

  -- Apply capability-gated features (inlay hints, format-on-save)
  apply_capability_features(client, bufnr)
end

return {
  {
    "b0o/SchemaStore.nvim", -- 🛍  JSON schemas for Neovim
    version = false, -- last release is way too old
    lazy = true,
  },
  {
    "neovim/nvim-lspconfig", -- Quickstart configs for Nvim LSP
    event = { "BufReadPre", "BufNewFile", "BufWritePre" },
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

      -- Register LspAttach for buffer-local keymaps and capability-gated features
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client then on_attach(client, args.buf) end
        end,
      })

      -- Clean up capability tracking on detach
      vim.api.nvim_create_autocmd("LspDetach", {
        group = vim.api.nvim_create_augroup("UserLspDetach", { clear = true }),
        callback = function(args)
          local prefix = args.data.client_id .. ":" .. args.buf
          for k, _ in pairs(_capability_applied) do
            if k:sub(1, #prefix) == prefix then _capability_applied[k] = nil end
          end
        end,
      })

      -- Handle dynamic capability registration (client/registerCapability).
      -- Some servers (e.g. gopls, clangd) register capabilities *after* the
      -- initial initialize response.  When that happens we re-evaluate
      -- capability-gated features for every buffer the client is attached to.
      local register_capability = vim.lsp.handlers["client/registerCapability"]
      vim.lsp.handlers["client/registerCapability"] = function(err, result, ctx)
        -- Call the built-in handler first so the client's capabilities are updated
        local resp = register_capability and register_capability(err, result, ctx)

        local client = vim.lsp.get_client_by_id(ctx.client_id)
        if client then
          -- Re-apply capability-gated features on every buffer this client serves
          for _, bufnr in ipairs(vim.lsp.get_buffers_by_client_id(ctx.client_id)) do
            apply_capability_features(client, bufnr)
          end
        end

        -- Return the response so the RPC layer sends it back to the server
        return resp
      end

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

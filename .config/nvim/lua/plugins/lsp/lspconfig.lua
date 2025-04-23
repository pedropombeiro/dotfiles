-- lsp-setup.nvim (https://github.com/junnplus/lsp-setup.nvim)
--   A simple wrapper for nvim-lspconfig and mason-lspconfig to easily setup LSP servers.

---@format disable-next
-- stylua: ignore
---@module "lazy"
---@type LazyKeysSpec[]
local keys = {
  { "[oH",         function() vim.lsp.inlay_hint.enable(true) end,  desc = "Enable inlay hints" },
  { "]oH",         function() vim.lsp.inlay_hint.enable(false) end, desc = "Disable inlay hints" },
  { "<leader>uh",  function() vim.lsp.inlay_hint.enable(false) end, desc = "Disable inlay hints" },
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
    event = { "BufReadPre", "BufNewFile" },
    keys = keys,
    dependencies = {
      { "saghen/blink.cmp" },
      {
        --- uses Mason to ensure installation of user specified LSP servers and will tell nvim-lspconfig what command
        --- to use to launch those servers.
        "williamboman/mason-lspconfig.nvim",
        enabled = function() return vim.fn.has("mac") == 1 end,
        dependencies = "williamboman/mason.nvim",
      },
    },
    ---@return PluginLspOpts
    opts = function()
      local function file_exists(name)
        local f = io.open(name, "r")
        if f ~= nil then
          io.close(f)
          return true
        else
          return false
        end
      end

      -- LSP Server Settings
      ---@class PluginLspOpts
      local lspopts = {
        servers = {
          bashls = {
            filetypes = { "sh", "bash", "zsh" },
          },
          docker_compose_language_service = {},
          dockerls = {},
          golangci_lint_ls = {},
          gopls = {
            settings = {
              gopls = {
                hints = {
                  rangeVariableTypes = true,
                  parameterNames = true,
                  constantValues = true,
                  assignVariableTypes = true,
                  compositeLiteralFields = true,
                  compositeLiteralTypes = true,
                  functionTypeParameters = true,
                },
              },
            },
          },
          jsonls = {
            -- lazy-load schemastore when needed
            on_new_config = function(new_config)
              new_config.settings.json.schemas = new_config.settings.json.schemas or {}
              vim.list_extend(new_config.settings.json.schemas, require("schemastore").json.schemas())
            end,
            settings = {
              json = {
                format = { enable = false },
                validate = { enable = true },
              },
            },
          },
          just = {},
          lua_ls = {
            single_file_support = true,
            settings = {
              Lua = {
                runtime = {
                  -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
                  version = "LuaJIT",
                },
                diagnostics = {
                  enable = true,
                  -- Get the language server to recognize the `Snacks` and `vim` globals
                  globals = { "Snacks", "vim" },
                  neededFileStatus = {
                    ["codestyle-check"] = "Any",
                  },
                },
                workspace = {
                  -- Make the server aware of Neovim runtime files
                  checkThirdParty = false,
                  library = {
                    vim.env.VIMRUNTIME,
                  },
                },
                completion = {
                  callSnippet = "Replace",
                },
                format = {
                  enable = false,
                  defaultConfig = {
                    indent_style = "space",
                    indent_size = "2",
                    quote_style = "double",
                  },
                },
                hint = {
                  enable = false,
                  arrayIndex = "Auto",
                  await = true,
                  paramName = "All",
                  paramType = true,
                  semicolon = "SameLine",
                  setType = false,
                },
              },
            },
          },
          jedi_language_server = {},
          ruby_lsp = {
            mason = false,
            cmd = { vim.fn.expand("~/.local/share/mise/shims/ruby-lsp") },
            init_options = {
              -- https://shopify.github.io/ruby-lsp/editors.html#all-initialization-options
              formatter = "standard",
              linters = { "standard" },
            },
          },
          sqlls = {},
          taplo = {},
          turbo_ls = {},
          vtsls = {},
          vimls = {},
          vale_ls = {},
          volar = {},
          yamlls = {
            filetypes = { "yaml", "yaml.docker-compose", "yaml.homeassistant" },
            -- Have to add this for yamlls to understand that we support line folding
            capabilities = {
              textDocument = {
                foldingRange = {
                  dynamicRegistration = false,
                  lineFoldingOnly = true,
                },
              },
              settings = {
                yaml = {
                  ["https://gitlab.com/gitlab-org/gitlab/-/raw/master/app/assets/javascripts/editor/schema/ci.json"] = "/.gitlab-ci.yml",
                },
              },
            },
            -- lazy-load schemastore when needed
            on_new_config = function(new_config)
              new_config.settings.yaml.schemas = new_config.settings.yaml.schemas or {}
              vim.list_extend(new_config.settings.yaml.schemas, require("schemastore").yaml.schemas())
            end,
            settings = {
              redhat = { telemetry = { enabled = false } },
              yaml = {
                keyOrdering = false,
                format = {
                  enable = false,
                },
                hover = true,
                completion = true,
                validate = true,
                schemastore = {
                  -- Must disable built-in schemaStore support to use
                  -- schemas from SchemaStore.nvim plugin
                  enable = false,
                  -- Avoid TypeError: Cannot read properties of undefined (reading 'length')
                  url = "",
                },
              },
            },
          },
        },
        -- Enable this to enable the builtin LSP code lenses on Neovim >= 0.10.0
        -- Be aware that you also will need to properly configure your LSP server to
        -- provide the code lenses.
        codelens = {
          enabled = false,
        },
        inlay_hints = { enabled = true },
      }
      local servers = lspopts.servers

      if file_exists(vim.fn.expand("~/Library/Arduino15/arduino-cli.yaml")) then
        servers.arduino_language_server = {
          -- stylua: ignore
          cmd = {
            "arduino-language-server",
            "-cli-config",
            "~/Library/Arduino15/arduino-cli.yaml", -- Generated with `arduino-cli config init`
            "-fqbn",
            "keyboardio:gd32:keyboardio_model_100",
            "-cli",
            "arduino-cli",
            "-clangd",
            "clangd",
          },
        }
        servers.clangd = {}
      end

      local install_dir = "/share/homes/admin/opt/vscode-home-assistant"
      if vim.fn.finddir(install_dir) then
        local lspconfig = require("lspconfig.configs")
        local util = require("lspconfig/util")

        -- add the default config for homeassistant
        lspconfig.homeassistant = {
          default_config = {
            cmd = { install_dir .. "/node_modules/.bin/ts-node", install_dir .. "/out/server/server.js", "--stdio" },
            filetypes = { "yaml.homeassistant" },
            root_dir = util.root_pattern(".HA_VERSION", "configuration.yaml"),
            settings = {},
          },
        }
        lspconfig.homeassistant.setup({})
      end

      return lspopts
    end,
    ---@param opts PluginLspOpts
    config = function(_, opts)
      local lspconfig = require("lspconfig")
      ---@type pmsp.neovim.Config
      local nvconfig = require("config")
      local border = nvconfig.ui.border
      local icons = nvconfig.ui.icons.diagnostics

      require("lspconfig.ui.windows").default_options.border = border

      local blink_cmp = package.loaded["blink.cmp"]
      if blink_cmp ~= nil then
        for server, config in pairs(opts.servers) do
          -- passing config.capabilities to blink.cmp merges with the capabilities in your
          -- `opts[server].capabilities, if you've defined it
          config.capabilities = blink_cmp.get_lsp_capabilities(config.capabilities)
          lspconfig[server].setup(config)
        end
      end

      ---@type vim.diagnostic.Opts
      vim.diagnostic.config({
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

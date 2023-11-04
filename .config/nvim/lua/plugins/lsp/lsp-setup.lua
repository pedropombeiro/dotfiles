-- lsp-setup.nvim (https://github.com/junnplus/lsp-setup.nvim)
--   A simple wrapper for nvim-lspconfig and mason-lspconfig to easily setup LSP servers.

---@format disable-next
-- stylua: ignore
local keys = {
  { '[g',          ':lua vim.diagnostic.goto_prev()<CR>',           desc = 'Next LSP diagnostic' },
  { ']g',          ':lua vim.diagnostic.goto_next()<CR>',           desc = 'Previous LSP diagnostic' },
  { '<f2>',        ':lua vim.lsp.buf.rename()<CR>',                 desc = 'Rename symbol' },
  { 'K',           ':lua vim.lsp.buf.hover()<CR>',                  desc = 'Hover' },
  { '<leader>K',   ':lua vim.lsp.buf.signature_help()<CR>',         desc = 'Signature help' },
  --{ "<leader>lca", ":lua vim.lsp.buf.code_action()<CR>",            desc = "List code actions" },       -- Replaced with nvim-code-action-menu
  { '<leader>lD',  ':lua vim.lsp.buf.declaration()<CR>',            desc = 'Go to declaration' },
  { '<leader>ly',  ':lua vim.lsp.buf.type_definition()<CR>',        desc = 'Go to type definition' },
  { '<leader>li',  ':lua vim.lsp.buf.implementation()<CR>',         desc = 'Go to implementation' },
  --{ "<leader>lr",  ":TroubleToggle lsp_references<CR>",             desc = "References" },
  --{ "<leader>ld",  ":TroubleToggle lsp_definitions<CR>",            desc = "Definitions" },
  --{ "<C-]>",       ":TroubleToggle lsp_definitions<CR>",            desc = "Definitions" },
  -- { '<leader>lf',  ':lua vim.lsp.buf.format({ async = true })<CR>', desc = 'Format buffer' },
  { '<leader>lwa', ':lua vim.lsp.buf.add_workspace_folder()<CR>', desc = 'Add workspace folder' },
  {
    '<leader>lwl',
    ':lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>',
    desc = 'List workspace folders',
  },
}

return {
  {
    'junnplus/lsp-setup.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    keys = keys,
    dependencies = {
      {
        'b0o/SchemaStore.nvim', -- 🛍  JSON schemas for Neovim
        version = false, -- last release is way too old
      },
      {
        'neovim/nvim-lspconfig', -- Quickstart configs for Nvim LSP
        dependencies = {
          'hrsh7th/cmp-nvim-lsp', -- nvim-cmp source for neovim builtin LSP client
          {
            --- uses Mason to ensure installation of user specified LSP servers and will tell nvim-lspconfig what command
            --- to use to launch those servers.
            'williamboman/mason-lspconfig.nvim',
            dependencies = 'williamboman/mason.nvim',
          },
        },
      },
      {
        --- Uses Mason to ensure installation of user specified LSP servers and will tell nvim-lspconfig what command
        --- to use to launch those servers.
        'williamboman/mason-lspconfig.nvim',
        dependencies = 'williamboman/mason.nvim',
      },
    },
    init = function()
      local config = require('config')

      local signs = {
        ---@diagnostic disable: undefined-field
        Error = config.icons.diagnostics.error .. ' ',
        Warn = config.icons.diagnostics.warning .. ' ',
        Hint = config.icons.diagnostics.hint .. ' ',
        Info = config.icons.diagnostics.info .. ' ',
        ---@diagnostic enable: undefined-field
      }
      for type, icon in pairs(signs) do
        local hl = 'DiagnosticSign' .. type
        vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = '' })
      end

      local m = require('mapx')
      m.nname('<leader>l', 'LSP')
      m.nname('<leader>lw', 'Workspace')
    end,
    config = function()
      --if !has_key(plugs, "trouble.nvim")
      --  nnoremap <silent> <leader>gd :lua vim.lsp.buf.definition()<CR>
      --  nnoremap <silent> <C-]> :lua vim.lsp.buf.definition()<CR>
      --  nnoremap <silent> <leader>gr :lua vim.lsp.buf.references()<CR>
      --  nnoremap <silent> <leader>xq :lua vim.diagnostic.setloclist()<CR>
      --endif

      if vim.fn.has('mac') ~= 1 then
        vim.env.DOTNET_SYSTEM_GLOBALIZATION_INVARIANT = 1 -- Needed for marksman LSP on systems missing ICU libraries
      end

      local function file_exists(name)
        local f = io.open(name, 'r')
        if f ~= nil then
          io.close(f)
          return true
        else
          return false
        end
      end

      local servers = {
        bashls = {},
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
            vim.list_extend(new_config.settings.json.schemas, require('schemastore').json.schemas())
          end,
          settings = {
            json = {
              format = { enable = false },
              validate = { enable = true },
            },
          },
        },
        lua_ls = {
          single_file_support = true,
          settings = {
            Lua = {
              runtime = {
                -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
                version = 'LuaJIT',
              },
              diagnostics = {
                enable = true,
                -- Get the language server to recognize the `vim` global
                globals = { 'vim' },
                neededFileStatus = {
                  ['codestyle-check'] = 'Any',
                },
              },
              workspace = {
                -- Make the server aware of Neovim runtime files
                library = vim.api.nvim_get_runtime_file('', true),
                checkThirdParty = false,
              },
              completion = {
                callSnippet = 'Replace',
              },
              format = {
                enable = false,
                defaultConfig = {
                  indent_style = 'space',
                  indent_size = '2',
                  quote_style = 'single',
                },
              },
              hint = {
                enable = false,
                arrayIndex = 'Auto',
                await = true,
                paramName = 'All',
                paramType = true,
                semicolon = 'SameLine',
                setType = false,
              },
            },
          },
        },
        sqlls = {},
        taplo = {},
        vimls = {},
        yamlls = {
          -- Have to add this for yamlls to understand that we support line folding
          capabilities = {
            textDocument = {
              foldingRange = {
                dynamicRegistration = false,
                lineFoldingOnly = true,
              },
            },
          },
          -- lazy-load schemastore when needed
          on_new_config = function(new_config)
            new_config.settings.yaml.schemas = new_config.settings.yaml.schemas or {}
            vim.list_extend(new_config.settings.yaml.schemas, require('schemastore').yaml.schemas())
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
                url = '',
              },
            },
          },
        },
      }
      if file_exists(vim.fn.expand('~/Library/Arduino15/arduino-cli.yaml')) then
        servers.arduino_language_server = {
          -- stylua: ignore
          cmd = {
            'arduino-language-server',
            '-cli-config', '~/Library/Arduino15/arduino-cli.yaml', -- Generated with `arduino-cli config init`
            '-fqbn', 'keyboardio:gd32:keyboardio_model_100',
            '-cli', 'arduino-cli',
            '-clangd', 'clangd'
          },
        }
        servers.clangd = {}
      end
      if vim.fn.executable('solargraph') == 1 then
        servers.solargraph = {
          flags = {
            debounce_text_changes = 150,
          },
        }
      end

      require('neodev').setup({
        library = {
          plugins = { 'plenary.nvim', 'neotest' },
          types = true,
        },
        runtime_path = true,
        experimental = { pathStrict = true },
      })

      require('lsp-setup').setup({
        default_mappings = false,
        inlay_hints = {
          enabled = false, -- TODO: Enable on Neovim 0.10+
        },
        -- Global capabilities
        capabilities = vim.lsp.protocol.make_client_capabilities(),
        servers = servers,
      })

      local install_dir = '/share/homes/admin/opt/vscode-home-assistant'
      if vim.fn.finddir(install_dir) then
        local lspconfig = require('lspconfig.configs')
        local util = require('lspconfig/util')

        -- add the default config for homeassistant
        lspconfig.homeassistant = {
          default_config = {
            cmd = { install_dir .. '/node_modules/.bin/ts-node', install_dir .. '/out/server/server.js', '--stdio' },
            filetypes = { 'yaml' },
            root_dir = util.root_pattern('configuration.yaml'),
            settings = {},
          },
        }
        lspconfig.homeassistant.setup({})
      end

      require('lspconfig.ui.windows').default_options.border = require('config').ui.border
    end,
  },
  {
    -- 💻 Neovim setup for init.lua and plugin development with full signature help, docs and completion for the nvim lua API.
    'folke/neodev.nvim',
    lazy = true,
    ft = { 'lua' },
  },
}

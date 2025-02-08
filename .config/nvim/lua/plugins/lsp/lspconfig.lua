-- lsp-setup.nvim (https://github.com/junnplus/lsp-setup.nvim)
--   A simple wrapper for nvim-lspconfig and mason-lspconfig to easily setup LSP servers.

---@format disable-next
-- stylua: ignore
local keys = {
  { '<leader>uh',  function() vim.lsp.inlay_hint.enable(false) end, desc = 'Disable inlay hints' },
  { '[oH',         function() vim.lsp.inlay_hint.enable(true) end,  desc = 'Enable inlay hints' },
  { ']oH',         function() vim.lsp.inlay_hint.enable(false) end, desc = 'Disable inlay hints' },
  { '[d',          function() vim.diagnostic.goto_prev() end,       desc = 'Previous LSP diagnostic' },
  { ']d',          function() vim.diagnostic.goto_next() end,       desc = 'Next LSP diagnostic' },
  { '<f2>',        function() vim.lsp.buf.rename() end,             desc = 'Rename symbol' },
  { 'K',           function() vim.lsp.buf.hover() end,              desc = 'Hover' },
  { '<leader>K',   function() vim.lsp.buf.signature_help() end,     desc = 'Signature help' },
  --{ "<leader>lca', function() vim.lsp.buf.code_action() end,        desc = "List code actions" },       -- Replaced with nvim-code-action-menu
  { '<leader>lD',  function() vim.lsp.buf.declaration() end,        desc = 'Go to declaration' },
  { '<leader>ly',  function() vim.lsp.buf.type_definition() end,    desc = 'Go to type definition' },
  { '<leader>li',  function() vim.lsp.buf.implementation() end,     desc = 'Go to implementation' },
  --{ "<leader>lr",  ':TroubleToggle lsp_references',             desc = "References" },
  --{ "<leader>ld",  ':TroubleToggle lsp_definitions',            desc = "Definitions" },
  --{ "<C-]>",       ':TroubleToggle lsp_definitions',            desc = "Definitions" },
  -- { '<leader>lf',  function() vim.lsp.buf.format({ async = true }) end, desc = 'Format buffer' },
  { '<leader>lwa', function() vim.lsp.buf.add_workspace_folder() end, desc = 'Add workspace folder' },
  {
    '<leader>lwl',
    function() print(vim.inspect(vim.lsp.buf.list_workspace_folders())) end,
    desc = 'List workspace folders',
  },
}

return {
  'neovim/nvim-lspconfig', -- Quickstart configs for Nvim LSP
  event = { 'BufReadPre', 'BufNewFile' },
  keys = keys,
  dependencies = {
    {
      'b0o/SchemaStore.nvim', -- 🛍  JSON schemas for Neovim
      version = false, -- last release is way too old
    },
    { 'saghen/blink.cmp' },
    {
      --- uses Mason to ensure installation of user specified LSP servers and will tell nvim-lspconfig what command
      --- to use to launch those servers.
      'williamboman/mason-lspconfig.nvim',
      enabled = function()
        return vim.fn.has('mac') == 1
      end,
      dependencies = 'williamboman/mason.nvim',
    },
  },
  init = function()
    local icons = require('config').ui.icons.diagnostics

    local signs = {
      ---@diagnostic disable: undefined-field
      Error = icons.error .. ' ',
      Warn = icons.warning .. ' ',
      Hint = icons.hint .. ' ',
      Info = icons.info .. ' ',
      ---@diagnostic enable: undefined-field
    }
    for type, icon in pairs(signs) do
      local hl = 'DiagnosticSign' .. type
      vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = '' })
    end
  end,
  opts = function()
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
      jedi_language_server = {},
      ruby_lsp = {
        mason = false,
        cmd = { vim.fn.expand('~/.local/share/mise/shims/ruby-lsp') },
        init_options = {
          formatter = 'standard',
          linters = { 'standard' },
        },
      },
      sqlls = {},
      taplo = {},
      vtsls = {},
      vimls = {},
      volar = {},
      yamlls = {
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
              ['https://gitlab.com/gitlab-org/gitlab/-/raw/master/app/assets/javascripts/editor/schema/ci.json'] = '/.gitlab-ci.yml',
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
          '-cli-config',
          '~/Library/Arduino15/arduino-cli.yaml', -- Generated with `arduino-cli config init`
          '-fqbn',
          'keyboardio:gd32:keyboardio_model_100',
          '-cli',
          'arduino-cli',
          '-clangd',
          'clangd',
        },
      }
      servers.clangd = {}
    end

    local install_dir = '/share/homes/admin/opt/vscode-home-assistant'
    if vim.fn.finddir(install_dir) then
      local lspconfig = require('lspconfig.configs')
      local util = require('lspconfig/util')

      -- add the default config for homeassistant
      lspconfig.homeassistant = {
        default_config = {
          cmd = { install_dir .. '/node_modules/.bin/ts-node', install_dir .. '/out/server/server.js', '--stdio' },
          filetypes = { 'home-assistant' },
          root_dir = util.root_pattern('.HA_VERSION', 'configuration.yaml'),
          settings = {},
        },
      }
      lspconfig.homeassistant.setup({})
    end

    return {
      servers = servers,
      inlay_hints = { enabled = true },
    }
  end,
  config = function(_, opts)
    --if !has_key(plugs, "trouble.nvim")
    --  nnoremap <silent> <leader>gd :lua vim.lsp.buf.definition()<CR>
    --  nnoremap <silent> <C-]> :lua vim.lsp.buf.definition()<CR>
    --  nnoremap <silent> <leader>gr :lua vim.lsp.buf.references()<CR>
    --  nnoremap <silent> <leader>xq :lua vim.diagnostic.setloclist()<CR>
    --endif

    local lspconfig = require('lspconfig')
    local border = require('config').ui.border

    require('lspconfig.ui.windows').default_options.border = border

    local isBlinkLoaded = package.loaded['blink.cmp'] ~= nil
    if isBlinkLoaded then
      for server, config in pairs(opts.servers) do
        -- passing config.capabilities to blink.cmp merges with the capabilities in your
        -- `opts[server].capabilities, if you've defined it
        config.capabilities = require('blink.cmp').get_lsp_capabilities(config.capabilities)
        lspconfig[server].setup(config)
      end
    end

    -- Show diagnostic source in float (e.g. goto_next, goto_prev)
    vim.diagnostic.config({
      severity_sort = true,
      virtual_text = {
        prefix = '●',
      },
      float = {
        focusable = false,
        style = 'minimal',
        border = border,
        source = false,
        header = '',
        suffix = '',
        prefix = '',
        format = function(value)
          return string.format('%s: [%s] %s', value.source, value.code, value.message)
        end,
      },
    })
  end,
}

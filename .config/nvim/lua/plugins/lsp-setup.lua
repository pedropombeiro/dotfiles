-- lsp-setup.nvim (https://github.com/junnplus/lsp-setup.nvim)
--   A simple wrapper for nvim-lspconfig and mason-lspconfig to easily setup LSP servers.

return {
  "junnplus/lsp-setup.nvim",
  event = "BufReadPre",
  dependencies = {
    {
      "neovim/nvim-lspconfig", -- Quickstart configs for Nvim LSP
      dependencies = {
        "hrsh7th/cmp-nvim-lsp", -- nvim-cmp source for neovim builtin LSP client
        {
          --- uses Mason to ensure installation of user specified LSP servers and will tell nvim-lspconfig what command
          --- to use to launch those servers.
          "williamboman/mason-lspconfig.nvim",
          dependencies = "williamboman/mason.nvim",
        },
        "b0o/schemastore.nvim", -- 🛍  JSON schemas for Neovim
      },
    },
    {
      --- Uses Mason to ensure installation of user specified LSP servers and will tell nvim-lspconfig what command
      --- to use to launch those servers.
      "williamboman/mason-lspconfig.nvim",
      dependencies = "williamboman/mason.nvim",
    }
  },
  init = function()
    local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
    for type, icon in pairs(signs) do
      local hl = "DiagnosticSign" .. type
      vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
    end

    local m = require("mapx")
    m.nnoremap("[g", ":lua vim.diagnostic.goto_prev()<CR>", "Next LSP diagnostic")
    m.nnoremap("]g", ":lua vim.diagnostic.goto_next()<CR>", "Previous LSP diagnostic")
    m.nnoremap("<f2>", ":lua vim.lsp.buf.rename()<CR>", "Rename symbol")
    m.nnoremap("K", ":lua vim.lsp.buf.hover()<CR>", "Hover")
    m.nnoremap("<leader>K", ":lua vim.lsp.buf.signature_help()<CR>", "Signature help")
    m.nname("<leader>l", "LSP")
    --m.nnoremap("<leader>lca", ":lua vim.lsp.buf.code_action()<CR>", "List code actions") -- Replaced with nvim-code-action-menu
    m.nnoremap("<leader>lD", ":lua vim.lsp.buf.declaration()<CR>", "Go to declaration")
    m.nnoremap("<leader>ly", ":lua vim.lsp.buf.type_definition()<CR>", "Go to type definition")
    m.nnoremap("<leader>li", ":lua vim.lsp.buf.implementation()<CR>", "Go to implementation")
    --m.nnoremap("<leader>lr", ":TroubleToggle lsp_references<CR>", "References")
    --m.nnoremap("<leader>ld", ":TroubleToggle lsp_definitions<CR>", "Definitions")
    --m.nnoremap("<C-]>", ":TroubleToggle lsp_definitions<CR>", "Definitions")
    m.nnoremap("<leader>lf", ":lua vim.lsp.buf.format({ async = true })<CR>", "Format buffer")
    m.nname("<leader>lw", "Workspace")
    m.nnoremap("<leader>lwa", ":lua vim.lsp.buf.add_workspace_folder()<CR>", "Add workspace folder")
    m.nnoremap("<leader>lwl", ":lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>",
      "List workspace folders")
  end,
  config = function()
    --if !has_key(plugs, "trouble.nvim")
    --  nnoremap <silent> <leader>gd :lua vim.lsp.buf.definition()<CR>
    --  nnoremap <silent> <C-]> :lua vim.lsp.buf.definition()<CR>
    --  nnoremap <silent> <leader>gr :lua vim.lsp.buf.references()<CR>
    --  nnoremap <silent> <leader>xq :lua vim.diagnostic.setloclist()<CR>
    --endif

    local function file_exists(name)
      local f = io.open(name, "r")
      if f ~= nil then io.close(f) return true else return false end
    end

    local servers = {
      bashls = {},
      dockerls = {},
      golangci_lint_ls = {},
      gopls = {},
      jsonls = {
        settings = {
          json = {
            schemas = require("schemastore").json.schemas(),
            validate = { enable = true },
          },
        },
      },
      marksman = {},
      sumneko_lua = {
        settings = {
          Lua = {
            runtime = {
              -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
              version = "LuaJIT",
            },
            diagnostics = {
              -- Get the language server to recognize the `vim` global
              globals = { "vim" },
              neededFileStatus = {
                ["codestyle-check"] = "Any",
              },
            },
            workspace = {
              -- Make the server aware of Neovim runtime files
              library = vim.api.nvim_get_runtime_file("", true),
              checkThirdParty = false,
            },
            completion = {
              callSnippet = "Replace",
            },
            format = {
              enable = true,
              defaultConfig = {
                indent_style = "space",
                indent_size = "2",
                quote_style = "double",
              },
            },
          },
        },
      },
      sqlls = {},
      taplo = {},
      vimls = {},
      yamlls = {
        settings = {
          yaml = {
            hover = true,
            completion = true,
            validate = true,
            schemastore = {
              enable = true,
              url = "https://www.schemastore.org/api/json/catalog.json",
            },
          },
        },
      },
    }
    if file_exists(vim.fn.expand("~/Library/Arduino15/arduino-cli.yaml")) then
      servers.arduino_language_server = {
        cmd = {
          "arduino-language-server",
          "-cli-config", "~/Library/Arduino15/arduino-cli.yaml", -- Generated with `arduino-cli config init`
          "-fqbn", "keyboardio:gd32:keyboardio_model_100",
          "-cli", "arduino-cli",
          "-clangd", "clangd"
        }
      }
      servers.clangd = {}
    end
    if vim.fn.executable("solargraph") == 1 then
      servers.solargraph = {
        flags = {
          debounce_text_changes = 150,
        }
      }
    end

    require("lsp-setup").setup({
      default_mappings = false,

      servers = servers,
    })
  end
}

-- lsp-setup.nvim (https://github.com/junnplus/lsp-setup.nvim)
--   A simple wrapper for nvim-lspconfig and mason-lspconfig to easily setup LSP servers.

--if !has_key(plugs, 'trouble.nvim')
--  nnoremap <silent> <leader>gd :lua vim.lsp.buf.definition()<CR>
--  nnoremap <silent> <C-]> :lua vim.lsp.buf.definition()<CR>
--  nnoremap <silent> <leader>gr :lua vim.lsp.buf.references()<CR>
--  nnoremap <silent> <leader>xq :lua vim.diagnostic.setloclist()<CR>
--endif

require("lsp-setup").setup({
  default_mappings = false,
  mappings = {
    ["[g"]         = "lua vim.diagnostic.goto_prev()",
    ["]g"]         = "lua vim.diagnostic.goto_next()",
    ["<f2>"]       = "lua vim.lsp.buf.rename()",
    ["K"]          = "lua vim.lsp.buf.hover()",
    ["<leader>K"]  = "lua vim.lsp.buf.signature_help()",
    ["<leader>gD"] = "lua vim.lsp.buf.declaration()",
    ["<leader>gy"] = "lua vim.lsp.buf.type_definition()",
    ["<leader>gi"] = "lua vim.lsp.buf.implementation()",
    ["<leader>gr"] = "TroubleToggle lsp_references",
    ["<leader>gd"] = "TroubleToggle lsp_definitions",
    ["<C-]>"]      = "TroubleToggle lsp_definitions",
    ["<leader>rn"] = "lua vim.lsp.buf.rename()",
    --["<leader>la"] = "lua vim.lsp.buf.code_action()", -- Replaced with nvim-code-action-menu
    ["<leader>lf"] = "lua vim.lsp.buf.format({ async = true })",
    ["<leader>wa"] = "lua vim.lsp.buf.add_workspace_folder()",
    ["<leader>wl"] = "lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))",
  },

  servers = {
    bashls = {},
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
    solargraph = {},
    sumneko_lua = {
      settings = {
        Lua = {
          diagnostics = {
            globals = { "vim" },
            neededFileStatus = {
              ["codestyle-check"] = "Any",
            },
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
})

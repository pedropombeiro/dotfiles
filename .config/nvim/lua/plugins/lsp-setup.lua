-- lsp-setup.nvim (https://github.com/junnplus/lsp-setup.nvim)
--   A simple wrapper for nvim-lspconfig and mason-lspconfig to easily setup LSP servers.

--if !has_key(plugs, "trouble.nvim")
--  nnoremap <silent> <leader>gd :lua vim.lsp.buf.definition()<CR>
--  nnoremap <silent> <C-]> :lua vim.lsp.buf.definition()<CR>
--  nnoremap <silent> <leader>gr :lua vim.lsp.buf.references()<CR>
--  nnoremap <silent> <leader>xq :lua vim.diagnostic.setloclist()<CR>
--endif

require("lsp-setup").setup({
  default_mappings = false,

  servers = {
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
    --solargraph = {},
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

local m = require("mapx").setup { global = "force", whichkey = true }
m.nname("<leader>l", "LSP")
m.nnoremap("[g", ":lua vim.diagnostic.goto_prev()<CR>", "Next LSP diagnostic")
m.nnoremap("]g", ":lua vim.diagnostic.goto_next()<CR>", "Previous LSP diagnostic")
m.nnoremap("<f2>", ":lua vim.lsp.buf.rename()<CR>", "Rename symbol")
m.nnoremap("K", ":lua vim.lsp.buf.hover()<CR>", "Hover")
m.nnoremap("<leader>K", ":lua vim.lsp.buf.signature_help()<CR>", "Signature help")
--m.nnoremap("<leader>la", ":lua vim.lsp.buf.code_action()<CR>", "List code actions") -- Replaced with nvim-code-action-menu
m.nnoremap("<leader>lD", ":lua vim.lsp.buf.declaration()<CR>", "Go to declaration")
m.nnoremap("<leader>ly", ":lua vim.lsp.buf.type_definition()<CR>", "Go to type definition")
m.nnoremap("<leader>li", ":lua vim.lsp.buf.implementation()<CR>", "Go to implementation")
m.nnoremap("<leader>lr", ":TroubleToggle lsp_references<CR>", "References")
m.nnoremap("<leader>ld", ":TroubleToggle lsp_definitions<CR>", "Definitions")
m.nnoremap("<C-]>", ":TroubleToggle lsp_definitions<CR>", "Definitions")
m.nnoremap("<leader>lf", ":lua vim.lsp.buf.format({ async = true })<CR>", "Format buffer")
m.nname("<leader>lw", "Workspace")
m.nnoremap("<leader>lwa", ":lua vim.lsp.buf.add_workspace_folder()<CR>", "Add workspace folder")
m.nnoremap("<leader>lwl", ":lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>", "List workspace folders")
if has("nvim")
  " -------------------- LSP ---------------------------------
  if has_key(plugs, 'trouble.nvim')
    nnoremap <silent> <leader>xx <cmd>TroubleToggle<cr>
    nnoremap <silent> <leader>xw <cmd>TroubleToggle workspace_diagnostics<cr>
    nnoremap <silent> <leader>xd <cmd>TroubleToggle document_diagnostics<cr>
    nnoremap <silent> <leader>xq <cmd>TroubleToggle quickfix<cr>
    nnoremap <silent> <leader>xl <cmd>TroubleToggle loclist<cr>
    nnoremap <silent> <leader>gr <cmd>TroubleToggle lsp_references<cr>
    nnoremap <silent> <leader>gd <cmd>TroubleToggle lsp_definitions<cr>
    nnoremap <silent> <C-]> <cmd>TroubleToggle lsp_definitions<cr>
  else
    nnoremap <silent> <leader>gd :lua vim.lsp.buf.definition()<CR>
    nnoremap <silent> <C-]> :lua vim.lsp.buf.definition()<CR>
    nnoremap <silent> <leader>gr :lua vim.lsp.buf.references()<CR>
    nnoremap <silent> <leader>xq :lua vim.diagnostic.setloclist()<CR>
  endif

  nnoremap <silent> <leader>gD :lua vim.lsp.buf.declaration()<CR>
  nnoremap <silent> K :lua vim.lsp.buf.hover()<CR>
  nnoremap <silent> <leader>gi :lua vim.lsp.buf.implementation()<CR>
  nnoremap <silent> <leader>K :lua vim.lsp.buf.signature_help()<CR>
  nnoremap <silent> <leader>wa :lua vim.lsp.buf.add_workspace_folder()<CR>
  nnoremap <silent> <leader>wr :lua vim.lsp.buf.remove_workspace_folder()<CR>
  nnoremap <silent> <leader>wl :lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>
  nnoremap <silent> <leader>gy :lua vim.lsp.buf.type_definition()<CR>
  nnoremap <silent> <leader>cr :lua vim.lsp.buf.rename()<CR>
  nnoremap <silent> <f2> :lua vim.lsp.buf.rename()<CR>
  nnoremap <silent> <leader>d :lua vim.diagnostic.open_float()<CR>
  nnoremap <silent> [g :lua vim.diagnostic.goto_prev()<CR>
  nnoremap <silent> ]g :lua vim.diagnostic.goto_next()<CR>
  nnoremap <silent> <leader>la :lua vim.lsp.buf.code_action()<CR>
  nnoremap <silent> <leader>lf :lua vim.lsp.buf.format { async = true }<CR>

  :lua << EOF
    local lspconfig = require('lspconfig')

    local on_attach = function(client, bufnr)
      require('completion').on_attach()

      buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

      -- Set autocommands conditional on server_capabilities
      if client.resolved_capabilities.document_highlight then
          require('lspconfig').util.nvim_multiline_command [[
          :hi LspReferenceRead cterm=bold ctermbg=red guibg=LightYellow
          :hi LspReferenceText cterm=bold ctermbg=red guibg=LightYellow
          :hi LspReferenceWrite cterm=bold ctermbg=red guibg=LightYellow
          augroup lsp_document_highlight
              autocmd!
              autocmd CursorHold <buffer> lua vim.lsp.buf.document_highlight()
              autocmd CursorMoved <buffer> lua vim.lsp.buf.clear_references()
          augroup END
          ]]
      end
    end

    require("mason").setup()

    ; -- null-ls.nvim (https://github.com/jose-elias-alvarez/null-ls.nvim)
    local null_ls = require("null-ls")

    null_ls.setup({
      sources = {
        null_ls.builtins.code_actions.gitsigns,
        null_ls.builtins.code_actions.shellcheck,
        null_ls.builtins.completion.spell,
        null_ls.builtins.diagnostics.checkmake,
        null_ls.builtins.diagnostics.yamllint,
        null_ls.builtins.diagnostics.zsh,
        null_ls.builtins.formatting.markdown_toc,
        null_ls.builtins.formatting.markdownlint,
        null_ls.builtins.formatting.nginx_beautifier,
        null_ls.builtins.formatting.pg_format,
        null_ls.builtins.formatting.rubocop,
        null_ls.builtins.formatting.shfmt,
        null_ls.builtins.formatting.stylua,
        null_ls.builtins.formatting.taplo,
        null_ls.builtins.formatting.yamlfmt,
        null_ls.builtins.hover.printenv,
      },
    })

    require("mason-null-ls").setup({
      ensure_installed = { "bashls", "gopls", "marksman", "sqls", "taplo", "vimls", "yamlls" },
      automatic_installation = false
    })

    ; -- lsp-format.nvim (https://github.com/lukas-reineke/lsp-format.nvim)
    require("lsp-format").setup {}

    lspconfig = require("lspconfig")
    lspconfig.bashls.setup {}
    lspconfig.dockerls.setup {}
    lspconfig.gopls.setup { on_attach = require("lsp-format").on_attach }
    lspconfig.solargraph.setup {}
    lspconfig.taplo.setup {}
    lspconfig.vimls.setup {}
    lspconfig.yamlls.setup {}
EOF
endif

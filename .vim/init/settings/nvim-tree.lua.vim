" -- nvim-tree.lua (https://github.com/nvim-tree/nvim-tree.lua/)
if has("nvim")
  lua << EOF
  -- disable netrw at the very start of your init.lua (strongly advised)
  vim.g.loaded_netrw = 1
  vim.g.loaded_netrwPlugin = 1

  -- set termguicolors to enable highlight groups
  vim.opt.termguicolors = true

  -- empty setup using defaults
  require("nvim-tree").setup()
EOF

  nnoremap <silent> <C-\> <Cmd>NvimTreeFindFileToggle<CR>
  vnoremap <silent> <C-\> <Cmd>NvimTreeFindFileToggle<CR>
endif

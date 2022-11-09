" -- nvim-tree.lua (https://github.com/nvim-tree/nvim-tree.lua/)
if has("nvim")
  lua << EOF
  -- disable netrw at the very start of your init.lua (strongly advised)
  vim.g.loaded_netrw = 1
  vim.g.loaded_netrwPlugin = 1

  require("nvim-tree").setup({
    reload_on_bufenter = true,
    sort_by = "case_sensitive",
    view = {
      adaptive_size = true,
      side = "right",
    },
    renderer = {
      group_empty = true,
      highlight_git = true,
      highlight_opened_files = "icon",
    },
    filters = {
      dotfiles = false,
      custom = { "^.DS_Store$", "^.git$", ".zwc$" },
    },
    actions = {
      expand_all = {
        exclude = { ".git" },
      },
      open_file = {
        quit_on_open = true,
      },
    },
  })
EOF

  nnoremap <silent> <C-\> <Cmd>NvimTreeFindFileToggle<CR>
  vnoremap <silent> <C-\> <Cmd>NvimTreeFindFileToggle<CR>
endif

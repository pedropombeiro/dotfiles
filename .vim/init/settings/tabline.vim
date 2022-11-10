" -- tabline.nvim (https://github.com/kdheepak/tabline.nvim)
if !has("nvim")
  exit
endif

lua << EOF
require'tabline'.setup {}
vim.cmd[[
  set guioptions-=e " Use showtabline in gui vim
  set sessionoptions+=tabpages,globals " store tabpages and globals in session
]]
EOF


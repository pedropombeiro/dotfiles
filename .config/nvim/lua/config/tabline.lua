-- tabline.nvim (https://github.com/kdheepak/tabline.nvim)
--  A "buffer and tab" tabline for neovim

require "tabline".setup {}

vim.cmd [[
  set guioptions-=e " Use showtabline in gui vim
  set sessionoptions+=tabpages,globals " store tabpages and globals in session
]]

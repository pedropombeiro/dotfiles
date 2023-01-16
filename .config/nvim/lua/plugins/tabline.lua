-- tabline.nvim (https://github.com/kdheepak/tabline.nvim)
--  A "buffer and tab" tabline for neovim

require "tabline".setup {}

vim.opt.sessionoptions:append { "tabpages", "globals" } -- store tabpages and globals in session

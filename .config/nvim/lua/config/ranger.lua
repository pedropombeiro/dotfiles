-- Ranger.vim (https://github.com/francoiscabrol/ranger.vim)
--  Ranger integration in vim and neovim

vim.g.ranger_map_keys = 0

local opts = { noremap = true, silent = true }
vim.keymap.set("n", "<leader>R", "<Cmd>Ranger<CR>", opts)

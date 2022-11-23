-- LazyGit (https://github.com/kdheepak/lazygit.nvim)
--  Plugin for calling lazygit from within neovim.

-- setup mapping to call :LazyGit
local opts = { noremap = true, silent = true }
vim.keymap.set("n", "<leader>gg", "<Cmd>LazyGit<CR>", opts)

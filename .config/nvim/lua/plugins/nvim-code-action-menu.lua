-- nvim-code-action-menu.vim (https://github.com/weilbith/nvim-code-action-menu)
--  Pop-up menu for code actions to show meta-information and diff preview

vim.keymap.set("n", "<leader>la", ":CodeActionMenu<CR>", { silent = true, noremap = true })

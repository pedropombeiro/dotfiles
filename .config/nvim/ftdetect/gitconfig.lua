vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile", "BufWritePost" }, {
  pattern = { vim.fn.expand("~") .. "/.config/dotfiles/git/gitconfig" },
  callback = function() vim.bo.filetype = "gitconfig" end,
})

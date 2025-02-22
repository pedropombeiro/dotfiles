vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile", "BufWritePost" }, {
  pattern = "git-revise-todo",
  callback = function() vim.bo.filetype = "gitrebase" end,
})

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile", "BufWritePost" }, {
  pattern = ".envrc",
  callback = function() vim.bo.filetype = "bash" end,
})

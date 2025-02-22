vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile", "BufWritePost" }, {
  pattern = { ".envrc", "*.env" },
  callback = function() vim.bo.syntax = "bash" end,
})

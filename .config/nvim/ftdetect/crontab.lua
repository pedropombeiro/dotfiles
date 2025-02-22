vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile", "BufWritePost" }, {
  pattern = { "crontab.txt", "*.crontab" },
  callback = function() vim.bo.filetype = "crontab" end,
})

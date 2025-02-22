vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile", "BufWritePost" }, {
  pattern = "*.service",
  callback = function() vim.bo.filetype = "systemd" end,
})

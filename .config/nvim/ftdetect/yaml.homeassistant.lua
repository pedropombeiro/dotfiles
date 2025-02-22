vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile", "BufWritePost" }, {
  pattern = {
    "*/config/home-assistant/*.yaml",
    "*/config/home-assistant/**/*.yaml",
  },
  callback = function() vim.bo.filetype = "yaml.homeassistant" end,
})

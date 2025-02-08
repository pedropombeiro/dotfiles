local ha_augroup = vim.api.nvim_create_augroup("home-assistant", { clear = true })

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "*/config/home-assistant/*.yaml", "*/config/home-assistant/**/*.yaml" },
  group = ha_augroup,
  callback = function(_ev)
    vim.opt_local.commentstring = "#\\ %s"
    vim.bo.filetype = "home-assistant"
    vim.bo.syntax = "yaml"
  end,
})

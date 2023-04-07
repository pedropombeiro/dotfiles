local ha_augroup = vim.api.nvim_create_augroup('homeassistant', { clear = true })

vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  pattern = { '*/config/home-assistant/*.yaml', '*/config/home-assistant/**/*.yaml' },
  group = ha_augroup,
  command = 'setlocal filetype=home-assistant syntax=yaml'
})

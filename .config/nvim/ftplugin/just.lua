vim.api.nvim_create_augroup('JustAutoFormatting', { clear = true })
vim.api.nvim_create_autocmd('BufWritePost', {
  pattern = { '.justfile', 'justfile' },
  group = 'JustAutoFormatting',
  command = ':silent !just --justfile %:p --fmt --unstable',
})

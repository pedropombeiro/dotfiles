-- gruvbox (https://github.com/gruvbox-community/gruvbox)
--  Retro groove color scheme for Vim - community maintained edition

vim.cmd([[
  augroup gruvbox_theme
    autocmd vimenter * ++nested colorscheme gruvbox
  augroup END
]])

vim.g.gruvbox_contrast_dark = "hard"
vim.g.gruvbox_italic = 1
vim.g.airline_theme = "gruvbox"

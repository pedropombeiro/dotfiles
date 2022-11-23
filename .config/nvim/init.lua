pcall(require, "impatient") -- precompile lua scripts for faster startup

vim.api.nvim_exec("autocmd!", false)

vim.g.mapleader = " "
vim.opt.timeoutlen = 500

-- Inspiration: https://github.com/skwp/dotfiles/blob/master/vim/settings.vim
local vimsettings = "~/.config/nvim/lua/core"
local settingsfiles = vim.fn.split(vim.fn.globpath(vimsettings, "*.lua"), "\n")

for _, fpath in ipairs(settingsfiles) do
  dofile(fpath)
end

-- Load plugins
require("packer_init")

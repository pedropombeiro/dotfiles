vim.api.nvim_exec("autocmd!", false)

vim.g.mapleader = " "
vim.opt.timeoutlen = 0

-- disable netrw at the very start of init.lua
--  (strongly advised so that nvim-tree can take over directory loading)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Load plugins
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Install plugins
-- https://github.com/folke/lazy.nvim
require("lazy").setup("plugins")

-- Inspiration: https://github.com/skwp/dotfiles/blob/master/vim/settings.vim
local vimsettings = "~/.config/nvim/lua/core"
local settingsfiles = vim.fn.split(vim.fn.globpath(vimsettings, "*.lua"), "\n")

for _, fpath in ipairs(settingsfiles) do
  dofile(fpath)
end

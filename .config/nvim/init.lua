if vim.fn.has('nvim-0.9') == 1 then
  vim.loader.enable() -- Enable experimental |lua-loader| that byte-compiles and caches lua files.
end

vim.api.nvim_exec2('autocmd!', {})

vim.g.mapleader = ' '
vim.g.maplocalleader = ','
vim.opt.timeoutlen = 0

-- disable netrw at the very start of init.lua
--  (strongly advised so that nvim-tree can take over directory loading)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Load plugins
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Install plugins
-- https://github.com/folke/lazy.nvim
require('lazy').setup({
  spec = {
    { import = 'plugins' },
    { import = 'plugins.lsp' },
  },
  defaults = {
    lazy = false,
    -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
    -- have outdated releases, which may break your Neovim install.
    version = false, -- always use the latest git commit
    -- version = "*", -- try installing the latest stable version for plugins that support semver
  },
  checker = {
    enabled = true, -- automatically check for plugin updates
    notify = true,
  },
  change_detection = {
    notify = false,
  },
  performance = {
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = {
        'gzip',
        -- "matchit",
        -- "matchparen",
        -- "netrwPlugin",
        'tarPlugin',
        'tohtml',
        'tutor',
        'zipPlugin',
      },
    },
  },
  ui = {
    border = require('config').ui.border,
  },
})

-- Inspiration: https://github.com/skwp/dotfiles/blob/master/vim/settings.vim
local vimsettings = '~/.config/nvim/lua/core'
local settingsfiles = vim.fn.split(vim.fn.globpath(vimsettings, '*.lua'), '\n')

for _, fpath in ipairs(settingsfiles) do
  dofile(fpath)
end

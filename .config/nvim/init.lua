local function try_require(module)
  local function requiref(module_try)
    require(module_try)
  end

  pcall(requiref, module)
end

try_require("impatient") -- precompile lua scripts for faster startup

vim.api.nvim_command("autocmd!")

vim.g.mapleader = " "
vim.opt.timeoutlen = 500

-- Get the defaults that most users want.
if vim.fn.filereadable(vim.fn.expand("$VIMRUNTIME/defaults.vim")) ~= 0 then
  vim.cmd("source \\$VIMRUNTIME/defaults.vim")
end

-- Inspiration: https://github.com/skwp/dotfiles/blob/master/vim/settings.vim
local vimsettings = "~/.config/nvim/settings"
local vimsettingsfiles = vim.fn.split(vim.fn.globpath(vimsettings, "*.vim"), "\n")

for _, fpath in ipairs(vimsettingsfiles) do
  vim.cmd("source" .. fpath)
end

-- Load plugins
require("plugins")

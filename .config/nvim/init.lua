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

-- Inspiration: https://github.com/skwp/dotfiles/blob/master/vim/settings.vim
local vimsettings = "~/.config/nvim/settings"
local settingsfiles = vim.fn.split(vim.fn.globpath(vimsettings, "*.{lua,vim}"), "\n")

for _, fpath in ipairs(settingsfiles) do
  if fpath:match("[^.]+$") == "lua" then
    dofile(fpath)
  else
    vim.cmd("source" .. fpath)
  end
end

-- Load plugins
require("plugins")

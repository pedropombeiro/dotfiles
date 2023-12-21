-- lazydocker.lua (https://github.com/crnvl96/lazydocker.nvim)
--  Plugin to open LazyDocker without quiting neovim.

return {
  'crnvl96/lazydocker.nvim',
  keys = {
    { '<leader>td', ':cd %:h | LazyDocker<CR>', desc = 'Open LazyDocker', noremap = true, silent = true },
  },
  opts = {},
  dependencies = {
    'MunifTanjim/nui.nvim',
  },
}

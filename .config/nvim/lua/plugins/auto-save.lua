-- auto-save.nvim (https://github.com/okuuva/auto-save.nvim)
--  🧶 Automatically save your changes in NeoVim

return {
  'okuuva/auto-save.nvim',
  version = '*',
  cmd = 'ASToggle', -- optional for lazy loading on command
  ft = { 'eruby', 'html' },
  opts = {
    debounce_delay = 500, -- delay after which a pending save is executed
  },
}

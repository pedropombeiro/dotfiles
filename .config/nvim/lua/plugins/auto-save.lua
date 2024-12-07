-- auto-save.nvim (https://github.com/okuuva/auto-save.nvim)
--  🧶 Automatically save your changes in NeoVim

return {
  'okuuva/auto-save.nvim',
  version = '*',
  cmd = 'ASToggle', -- optional for lazy loading on command
  ft = { 'eruby', 'html' },
  opts = {
    debounce_delay = 500, -- delay after which a pending save is executed
    trigger_events = {
      immediate_save = { 'BufLeave', 'FocusLost' }, -- vim events that trigger an immediate save
      defer_save = {
        { 'InsertLeave', 'TextChanged', pattern = { '*.erb', '*.css', '*.scss' } },
      },
      cancel_deferred_save = { 'InsertEnter' }, -- vim events that cancel a pending deferred save
    },
  },
}

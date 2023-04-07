-- trouble.nvim (https://github.com/folke/trouble.nvim)
--  🚦 A pretty diagnostics, references, telescope results, quickfix and location list to help you solve all
--  the trouble your code is causing.

return {
  'folke/trouble.nvim',
  cmd = { 'TroubleToggle', 'Trouble' },
  keys = {
    { '<leader>xx', '<cmd>TroubleToggle<cr>',                       desc = 'Toggle Trouble window' },
    { '<leader>xw', '<cmd>TroubleToggle workspace_diagnostics<cr>', desc = 'Toggle workspace diagnostics' },
    { '<leader>xd', '<cmd>TroubleToggle document_diagnostics<cr>',  desc = 'Toggle document diagnostics' },
    { '<leader>xq', '<cmd>TroubleToggle quickfix<cr>',              desc = 'Toggle quickfix window' },
    { '<leader>xl', '<cmd>TroubleToggle loclist<cr>',               desc = 'Toggle loclist window' },
  },
  dependencies = 'kyazdani42/nvim-web-devicons',
  init = function()
    require('mapx').nname('<leader>x', 'Trouble 🚦')
  end,
  opts = { use_diagnostic_signs = true },
}

-- trouble.nvim (https://github.com/folke/trouble.nvim)
--  🚦 A pretty diagnostics, references, telescope results, quickfix and location list to help you solve all
--  the trouble your code is causing.

return {
  'folke/trouble.nvim',
  cmd = { 'TroubleToggle', 'Trouble' },
  keys = {
    { '<leader>xw', '<cmd>Trouble diagnostics toggle<cr>', desc = 'Toggle workspace diagnostics' },
    { '<leader>xd', '<cmd>Trouble diagnostics toggle filter.buf=0<cr>', desc = 'Toggle document diagnostics' },
    { '<leader>xq', '<cmd>Trouble qflist toggle<cr>', desc = 'Toggle quickfix window' },
    { '<leader>xl', '<cmd>Trouble loclist toggle<cr>', desc = 'Toggle loclist window' },
    {
      '[X',
      function()
        require('trouble').first({ skip_groups = true, jump = true })
      end,
      desc = 'First Trouble 🚦 item',
    },
    {
      '[x',
      function()
        require('trouble').previous({ skip_groups = true, jump = true })
      end,
      desc = 'Previous Trouble 🚦 item',
    },
    {
      ']x',
      function()
        require('trouble').next({ skip_groups = true, jump = true })
      end,
      desc = 'Next Trouble 🚦 item',
    },
    {
      ']X',
      function()
        require('trouble').last({ skip_groups = true, jump = true })
      end,
      desc = 'Last Trouble 🚦 item',
    },
  },
  dependencies = 'kyazdani42/nvim-web-devicons',
  init = function()
    require('mapx').nname('<leader>x', 'Trouble 🚦')

    vim.cmd('highlight link TroubleNormal NormalFloat')
  end,
  opts = { use_diagnostic_signs = true },
}

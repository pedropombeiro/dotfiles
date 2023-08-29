return {
  'folke/edgy.nvim',
  event = 'VeryLazy',
  init = function()
    vim.opt.laststatus = 3
    vim.opt.splitkeep = 'screen'
  end,
  cond = function()
    return not vim.g.started_by_firenvim
  end,
  opts = {
    bottom = {
      -- toggleterm / lazyterm at the bottom with a height of 40% of the screen
      {
        ft = 'toggleterm',
        size = { height = 0.4 },
        -- exclude floating windows
        filter = function(buf, win)
          return vim.api.nvim_win_get_config(win).relative == ''
        end,
      },
      {
        ft = 'lazyterm',
        title = 'LazyTerm',
        size = { height = 0.4 },
        filter = function(buf)
          return not vim.b[buf].lazyterm_cmd
        end,
      },
      'Trouble',
      { ft = 'qf',            title = 'QuickFix' },
      {
        ft = 'help',
        size = { height = 20 },
        -- only show help buffers
        filter = function(buf)
          return vim.bo[buf].buftype == 'help'
        end,
      },
      { ft = 'spectre_panel', size = { height = 0.4 } },
    },
    -- enable this on Neovim <= 0.10.0 to properly fold edgebar windows.
    -- Not needed on a nightly build >= June 5, 2023.
    fix_win_height = vim.fn.has('nvim-0.10.0') == 0,
  },
}

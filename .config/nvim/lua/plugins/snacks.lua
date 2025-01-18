-- snacks.nvim (https://github.com/folke/snacks.nvim)
--  🍿 A collection of QoL plugins for Neovim

return {
  'folke/snacks.nvim',
  cond = function()
    return not vim.g.started_by_firenvim
  end,
  lazy = false,
  keys = {
    {
      '<leader>fn',
      function()
        Snacks.notifier.show_history()
      end,
      desc = 'Notification History',
    },
    {
      '<leader>dn',
      function()
        Snacks.notifier.hide()
      end,
      desc = 'Dismiss All Notifications',
    },
  },
  ---@type snacks.Config
  opts = function()
    local config = require('config')
    local icons = config.ui.icons.diagnostics
    local function vim_version()
      return vim.version().major .. '.' .. vim.version().minor .. '.' .. vim.version().patch
    end

    return {
      dashboard = {
        preset = {
          header = [[            ]]
            .. vim_version()
            .. [[

███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝]],
        },
        sections = {
          { section = 'header' },
          {
            pane = 2,
            padding = { 7, 0 },
          },
          { icon = ' ', key = 'm', desc = 'Mason', action = '<cmd>Mason<CR>' },
          { section = 'keys', padding = 1 },
          { pane = 2, icon = ' ', title = 'Recent Files', section = 'recent_files', indent = 2, padding = { 2, 2 } },
          { pane = 2, icon = ' ', title = 'Projects', section = 'projects', indent = 2, padding = 2 },
          {
            pane = 2,
            icon = ' ',
            title = 'Git Status',
            section = 'terminal',
            enabled = function()
              return Snacks.git.get_root() ~= nil
            end,
            cmd = 'git --no-pager diff --stat -B -M -C',
            height = 10,
            padding = 1,
            ttl = 5 * 60,
            indent = 3,
          },
          { section = 'startup' },
        },
      },
      notifier = {
        enabled = true,
        timeout = 3000,
        icons = {
          ---@diagnostic disable: undefined-field
          error = icons.error,
          warn = icons.warning,
          info = icons.info,
          debug = icons.debug,
          trace = icons.trace,
          ---@diagnostic enable: undefined-field
        },
      },
    }
  end,
}

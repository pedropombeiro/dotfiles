-- snacks.nvim (https://github.com/folke/snacks.nvim)
--  🍿 A collection of QoL plugins for Neovim

return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  keys = {
    { '<leader>bd', function() Snacks.bufdelete() end, desc = 'Close buffer', silent = true },

    { '<leader>fn', function() Snacks.dashboard.open() end, desc = 'Dashboard', silent = true },

    { '<leader>fn', function() Snacks.notifier.show_history() end, desc = 'Notification History', silent = true },
    { '<leader>dn', function() Snacks.notifier.hide() end, desc = 'Dismiss All Notifications', silent = true },

    { '<leader>tn', function() Snacks.terminal() end, desc = 'Open terminal', silent = true },

    { '<leader>-',  function() Snacks.scratch() end, desc = 'Toggle Scratch Buffer' },
    { '<leader>S',  function() Snacks.scratch.select() end, desc = 'Select Scratch Buffer' },

    { '[w', function() Snacks.words.jump(-1, true) end, desc = 'Previous word reference', silent = true },
    { ']w', function() Snacks.words.jump(1, true) end, desc = 'Next word reference', silent = true },
  },
  init = function()
    require('which-key').add({
      { '<leader>b', group = 'Bclose' },
    })
  end,
  opts = function()
    local config = require('config')
    local icons = config.ui.icons.diagnostics
    local function vim_version()
      return vim.version().major .. '.' .. vim.version().minor .. '.' .. vim.version().patch
    end

    return {
      bigfile = {
        enabled = not vim.g.started_by_firenvim,
      },
      dashboard = {
        enabled = not vim.g.started_by_firenvim,
        preset = {
          header = [[
      ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗ ]] .. vim_version() .. '\n' .. [[
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝]],
        },
        sections = {
          { section = 'header' },
          { pane = 2, section = 'terminal', cmd = "curl -s 'https://wttr.in/?0'", height = 8 },
          {
            { icon = ' ', key = 'f', desc = 'Find File', action = ":lua Snacks.dashboard.pick('files')" },
            { icon = ' ', key = 'n', desc = 'New File', action = ':ene | startinsert' },
            { icon = ' ', key = 'g', desc = 'Find Text', action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = ' ', key = '<leader>fgg', desc = 'Git Grep', action = ":lua require('git_grep').live_grep()" },
            { icon = ' ', key = 'r', desc = 'Recent Files', action = ":lua Snacks.dashboard.pick('oldfiles')" },
            {
              icon = ' ',
              key = 'c',
              desc = 'Config',
              action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})",
            },
            { icon = ' ', key = 's', desc = 'Restore Session', section = 'session' },
            { icon = '󰒲 ', key = 'l', desc = 'Lazy', action = ':Lazy', enabled = package.loaded.lazy ~= nil },
            { icon = ' ', key = 'm', desc = 'Mason', action = ':Mason' },
            { icon = ' ', key = 'q', desc = 'Quit', action = ':qa', padding = 1 },
          },
          { pane = 2, icon = ' ', title = 'Recent Files', section = 'recent_files', indent = 2, padding = 2 },
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
            padding = 1,
            ttl = 5 * 60,
            indent = 2,
          },
          { section = 'startup' },
        },
      },
      indent = {
        animate = {
          duration = {
            step = 20, -- ms per step
            total = 200, -- maximum duration
          },
        },
      },
      input = {
        enabled = true,
      },
      lazygit = {
        enabled = not vim.g.started_by_firenvim,
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
      quickfile = {
        enabled = true,
      },
      scope = {
        enabled = true,
      },
      scratch = {
        enabled = true,
      },
      statuscolumn = {
        left = { 'mark', 'fold', 'sign' }, -- priority of signs on the left (high to low)
        right = { 'git' }, -- priority of signs on the right (high to low)
        folds = {
          open = false, -- show open fold icons
          git_hl = true, -- use Git Signs hl for fold icons
        },
        git = {
          -- patterns to match Git signs
          patterns = { 'GitSign' },
        },
        refresh = 50, -- refresh at most every 50ms
      },
      terminal = {
        enabled = not vim.g.started_by_firenvim,
      },
      win = {
        border = 'rounded',
      },
      words = {
        enabled = true,
        notify_jump = true,
      },
    }
  end,
}

-- snacks.nvim (https://github.com/folke/snacks.nvim)
--  🍿 A collection of QoL plugins for Neovim

local function refresh_gitsigns()
  local plugins = require('lazy.core.config').plugins
  if plugins['gitsigns.nvim'] ~= nil and plugins['gitsigns.nvim']._.loaded ~= nil then
    -- ensure that Gitsigns refreshes with new state after closing Lazygit
    require('gitsigns').refresh()
  end
end

return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  keys = {
    { '<leader>bd', function() Snacks.bufdelete() end, desc = 'Close buffer' },
    {
      '<leader>fn',
      function()
        Snacks.dashboard.open()
      end,
      desc = 'Dashboard',
    },
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
    {
      '<leader>tg',
      function()
        Snacks.lazygit.open()

        refresh_gitsigns()
      end,
      desc = 'Open LazyGit',
    },
    {
      '<leader>tC',
      function()
        Snacks.lazygit.log_file()

        refresh_gitsigns()
      end,
      desc = 'Open LazyGit for current file',
    },
    {
      '<leader>tn', function() Snacks.terminal() end, desc = 'Open terminal',
    }
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
      terminal = {
        enabled = not vim.g.started_by_firenvim,
      },
    }
  end,
}

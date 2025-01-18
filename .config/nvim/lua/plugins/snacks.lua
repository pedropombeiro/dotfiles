-- snacks.nvim (https://github.com/folke/snacks.nvim)
--  🍿 A collection of QoL plugins for Neovim

local function refresh_gitsigns()
  local plugins = require('lazy.core.config').plugins
  if plugins['gitsigns.nvim'] ~= nil and plugins['gitsigns.nvim']._.loaded ~= nil then
    -- ensure that Gitsigns refreshes with new state after closing Lazygit
    vim.cmd([[execute 'Gitsigns refresh']])
  end
end

local config = require('config')
local icons = config.ui.icons.diagnostics
local function vim_version()
  return vim.version().major .. '.' .. vim.version().minor .. '.' .. vim.version().patch
end

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
  },
  ---@type snacks.Config
  opts = {
    bigfile = {},
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
    lazygit = {},
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
    quickfile = {},
  },
}

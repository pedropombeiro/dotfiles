-- snacks.nvim (https://github.com/folke/snacks.nvim)
--  🍿 A collection of QoL plugins for Neovim

return {
  'folke/snacks.nvim',
  cond = function()
    return not vim.g.started_by_firenvim
  end,
  ---@type snacks.Config
  opts = {
    dashboard = {
      preset = {
        header = [[            ]]
          .. vim.version().major
          .. '.'
          .. vim.version().minor
          .. '.'
          .. vim.version().patch
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
        { icon = ' ', key = 'm', desc = 'Mason', action = '<cmd>Mason<CR>', padding = { 1, 1 } },
        { section = 'keys', gap = 1, padding = 1 },
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
  },
}

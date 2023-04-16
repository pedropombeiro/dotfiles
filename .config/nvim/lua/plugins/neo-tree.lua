-- neo-tree.lua (https://github.com/nvim-neo-tree/neo-tree.nvim)
--  Neovim plugin to manage the file system and other tree like structures.

return {
  'nvim-neo-tree/neo-tree.nvim',
  branch = 'v2.x',
  cond = function() return not vim.g.started_by_firenvim end,
  cmd = 'Neotree',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'kyazdani42/nvim-web-devicons', -- not strictly required, but recommended
    'MunifTanjim/nui.nvim',
  },
  keys = {
    {
      '<C-\\>',
      '<Cmd>Neotree filesystem toggle reveal position=right<CR>',
      mode = { 'n', 'v' },
      desc = 'Toggle file explorer'
    },
    {
      'gx', -- Restore URL handling from disabled netrw plugin
      function()
        if vim.fn.has('mac') == 1 then
          vim.cmd [[call jobstart(['open', expand('<cfile>')], {'detach': v:true})<CR>]]
        elseif vim.fn.has('unix') == 1 then
          vim.cmd [[call jobstart(['xdg-open', expand('<cfile>')], {'detach': v:true})<CR>]]
        else
          print('Error: gx is not supported on this OS!')
        end
      end,
      'Open URL'
    },
  },
  init = function()
    vim.g.neo_tree_remove_legacy_commands = 1
    if vim.fn.argc() == 1 then
      local stat = vim.loop.fs_stat(vim.fn.argv(0))
      if stat and stat.type == 'directory' then
        require('neo-tree')
      end
    end
  end,
  opts = function()
    ---@diagnostic disable: undefined-field
    local icons = require('config').icons
    ---@diagnostic enable: undefined-field

    vim.fn.sign_define('DiagnosticSignError', { text = icons.diagnostics.error, texthl = 'DiagnosticSignError' })
    vim.fn.sign_define('DiagnosticSignWarn', { text = icons.diagnostics.warning, texthl = 'DiagnosticSignWarn' })
    vim.fn.sign_define('DiagnosticSignInfo', { text = icons.diagnostics.info, texthl = 'DiagnosticSignInfo' })
    vim.fn.sign_define('DiagnosticSignHint', { text = icons.diagnostics.hint, texthl = 'DiagnosticSignHint' })

    return {
      default_component_configs = {
        icon = {
          folder_closed = icons.folder.collapsed,
          folder_open   = icons.folder.expanded
        },
        indent = {
          expander_collapsed = icons.expander.collapsed,
          expander_expanded  = icons.expander.expanded,
          expander_highlight = 'NeoTreeExpander',
        },
        modified = {
          symbol = icons.symbols.modified,
        },
        git_status = {
          symbols = {
            -- Change type
            deleted = icons.symbols.removed,   -- this can only be used in the git_status source
            renamed = icons.symbols.renamed,   -- this can only be used in the git_status source
          }
        },
      },
      filesystem = {
        bind_to_cwd = false,
        follow_current_file = true,
        use_libuv_file_watcher = true,
        filtered_items = {
          hide_dotfiles   = false,
          hide_gitignored = true,
          hide_hidden     = true, -- only works on Windows for hidden files/directories
          hide_by_name    = {
            '.git',
            'node_modules',
          },
          hide_by_pattern = { -- uses glob style patterns
            '*.zwc',
          },
          never_show      = { -- remains hidden even if visible is toggled to true, this overrides always_show
            '.DS_Store',
            'thumbs.db'
          },
        },
        find_args = {
          fd = {
            '-uu',
            '--exclude',
            '.git',
            '--exclude',
            'node_modules',
            '--exclude',
            'target',
          },
        },
      },
      window = {
        position = 'right',
        mappings = {
          ['<space>'] = 'none',
        },
      },
    }
  end,
  deactivate = function()
    vim.cmd([[Neotree close]])
  end,
}

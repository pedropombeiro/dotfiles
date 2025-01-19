-- neo-tree.lua (https://github.com/nvim-neo-tree/neo-tree.nvim)
--  Neovim plugin to manage the file system and other tree like structures.

return {
  'nvim-neo-tree/neo-tree.nvim',
  branch = 'v3.x',
  cond = function()
    return not vim.g.started_by_firenvim
  end,
  cmd = 'Neotree',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'kyazdani42/nvim-web-devicons', -- not strictly required, but recommended
    'MunifTanjim/nui.nvim',
    {
      's1n7ax/nvim-window-picker',
      name = 'window-picker',
      event = 'VeryLazy',
      version = '2.*',
      opts = function()
        local colors = require('config').theme.colors

        return {
          use_winbar = 'always',
          highlights = {
            statusline = {
              focused = {
                fg = colors.fg,
                bg = colors.orange_bg,
              },
              unfocused = {
                fg = colors.fg,
                bg = colors.green_bg,
              },
            },
            winbar = {
              focused = {
                fg = colors.fg,
                bg = colors.orange_bg,
              },
              unfocused = {
                fg = colors.fg,
                bg = colors.green_bg,
              },
            },
          },
        }
      end,
    },
  },
  keys = {
    {
      '<C-\\>',
      '<Cmd>Neotree filesystem toggle reveal position=right<CR>',
      mode = { 'n', 'v' },
      desc = 'Toggle file explorer',
    },
    {
      'gx', -- Restore URL handling from disabled netrw plugin
      function()
        vim.ui.open(vim.fn.expand('<cfile>'))
      end,
      'Open URL',
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
  opts = function(_, opts)
    ---@diagnostic disable: undefined-field
    local icons = require('config').ui.icons
    ---@diagnostic enable: undefined-field

    vim.fn.sign_define('DiagnosticSignError', { text = icons.diagnostics.error, texthl = 'DiagnosticSignError' })
    vim.fn.sign_define('DiagnosticSignWarn', { text = icons.diagnostics.warning, texthl = 'DiagnosticSignWarn' })
    vim.fn.sign_define('DiagnosticSignInfo', { text = icons.diagnostics.info, texthl = 'DiagnosticSignInfo' })
    vim.fn.sign_define('DiagnosticSignHint', { text = icons.diagnostics.hint, texthl = 'DiagnosticSignHint' })

    -- +Snacks
    local function on_move(data)
      Snacks.rename.on_rename_file(data.source, data.destination)
    end
    local events = require('neo-tree.events')
    opts.event_handlers = opts.event_handlers or {}
    vim.list_extend(opts.event_handlers, {
      { event = events.FILE_MOVED, handler = on_move },
      { event = events.FILE_RENAMED, handler = on_move },
    })
    -- -Snacks

    return {
      default_component_configs = {
        icon = {
          folder_empty = icons.folder.empty,
          folder_empty_open = icons.folder.empty_open,
          folder_closed = icons.folder.collapsed,
          folder_open = icons.folder.expanded,
          default = '',
        },
        indent = {
          expander_collapsed = icons.expander.collapsed,
          expander_expanded = icons.expander.expanded,
          expander_highlight = 'NeoTreeExpander',
        },
        modified = {
          symbol = icons.symbols.modified,
        },
        git_status = {
          symbols = {
            -- Change type
            deleted = icons.symbols.removed, -- this can only be used in the git_status source
            renamed = icons.symbols.renamed, -- this can only be used in the git_status source
            -- Status type
            unstaged = icons.symbols.unstaged,
          },
        },
      },
      document_symbols = {
        kinds = {
          File = { icon = '󰈙', hl = 'Tag' },
          Namespace = { icon = '󰌗', hl = 'Include' },
          Package = { icon = '󰏖', hl = 'Label' },
          Class = { icon = '󰌗', hl = 'Include' },
          Property = { icon = '󰆧', hl = '@property' },
          Enum = { icon = '󰒻', hl = '@number' },
          Function = { icon = '󰊕', hl = 'Function' },
          String = { icon = '󰀬', hl = 'String' },
          Number = { icon = '󰎠', hl = 'Number' },
          Array = { icon = '󰅪', hl = 'Type' },
          Object = { icon = '󰅩', hl = 'Type' },
          Key = { icon = '󰌋', hl = '' },
          Struct = { icon = '󰌗', hl = 'Type' },
          Operator = { icon = '󰆕', hl = 'Operator' },
          TypeParameter = { icon = '󰊄', hl = 'Type' },
          StaticMethod = { icon = '󰠄 ', hl = 'Function' },
        },
      },
      sources = { 'filesystem', 'buffers', 'git_status', 'document_symbols' },
      open_files_do_not_replace_types = { 'terminal', 'Trouble', 'qf', 'Outline', 'trouble' },
      filesystem = {
        bind_to_cwd = false,
        follow_current_file = { enabled = true },
        use_libuv_file_watcher = true,
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = true,
          hide_hidden = true, -- only works on Windows for hidden files/directories
          hide_by_name = {
            '.git',
            'node_modules',
          },
          hide_by_pattern = { -- uses glob style patterns
            '*.zwc',
          },
          never_show = { -- remains hidden even if visible is toggled to true, this overrides always_show
            '.DS_Store',
            'thumbs.db',
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
  config = function(_, opts)
    require('neo-tree').setup(opts)

    -- refresh neotree git status when closing a lazygit terminal
    vim.api.nvim_create_autocmd('TermClose', {
      pattern = '*lazygit',
      callback = function()
        if package.loaded['neo-tree.sources.git_status'] then
          require('neo-tree.sources.git_status').refresh()
        end
      end,
    })
  end,
  deactivate = function()
    vim.cmd([[Neotree close]])
  end,
}

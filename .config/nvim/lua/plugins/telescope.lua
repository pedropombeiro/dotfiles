-- Telescope (https://github.com/nvim-telescope/telescope.nvim)
--  Find, Filter, Preview, Pick. All lua, all the time.

---@format disable-next
-- stylua: ignore
local keys = {
  -- File operations
  { '<leader>f', group = 'Telescope' },
  { '<leader>ff',    '<Cmd>Telescope find_files<CR>',      desc = 'Files', icon = '' },
  { '<leader>fr',    '<Cmd>Telescope live_grep<CR>',       desc = 'Live grep (rg)', icon = '' },
  { '<leader>fF',    '<Cmd>Telescope resume<CR>',          desc = 'Resume last Telescope command/query' },
  { '<leader><Tab>', '<Cmd>Telescope keymaps<CR>',         desc = 'Keymaps', icon = '' },
  { '<leader>fb',    '<Cmd>Telescope buffers<CR>',         desc = 'Buffers' },
  { '<leader>fH',    '<Cmd>Telescope highlights<CR>',      desc = 'Highlight groups' },
  { '<leader>fK',    '<Cmd>Telescope man_pages<CR>',       desc = 'Man pages', icon = '' },
  { '<leader>fl',    '<Cmd>Telescope loclist<CR>',         desc = 'Location list', icon = '' },
  { '<leader>fq',    '<Cmd>Telescope quickfix<CR>',        desc = 'Quickfix list', icon = '' },
  { '<leader>fT',    '<Cmd>Telescope filetypes<CR>',       desc = 'Filetypes' },
  { '<leader>fh',    '<Cmd>Telescope oldfiles<CR>',        desc = 'Old files' },
  { '<leader>f:',    '<Cmd>Telescope command_history<CR>', desc = 'Command history', icon = '' },
  { '<leader>f/',    '<Cmd>Telescope search_history<CR>',  desc = 'Search history', icon = '󱝩' },
  { '<leader>f`',    '<Cmd>Telescope marks<CR>',           desc = 'Marks', icon = '' },
  { "<leader>f'",    '<Cmd>Telescope marks<CR>',           desc = 'Marks', icon = '' },
  { '<leader>f.',    '<Cmd>Telescope jumplist<CR>',        desc = 'Jump list', icon = '' },
  { '<leader>f"',    '<Cmd>Telescope registers<CR>',       desc = 'Registers' },
  { '<leader>fO',    '<Cmd>Telescope vim_options<CR>',     desc = 'Vim options', icon = '' },
  { '<leader>fs',    '<Cmd>Telescope spell_suggest<CR>',   desc = 'Spelling suggestions', icon = '󱣩' },
  { '<leader>fp',    '<Cmd>Telescope lazy<CR>',            desc = 'Plugins', icon = '' },

  -- Git operations
  { '<leader>fg', group = 'Telescope (Git)', icon = '' },
  { '<leader>fgb', '<Cmd>Telescope git_branches<CR>', desc = 'Git branches', icon = '' },
  { '<leader>fgc', '<Cmd>Telescope git_commits<CR>',  desc = 'Git commits', icon = '' },
  { '<leader>fgC', '<Cmd>Telescope git_bcommits<CR>', desc = 'Git commits (buffer)', icon = '' },
  {
    '<leader>fgg',
    function()
      require('git_grep').live_grep()
    end,
    desc = 'Git grep'
  },
  { '<leader>fgf', '<Cmd>Telescope git_files<CR>', desc = 'Git files', icon = '' },
  { '<leader>fgS', '<Cmd>Telescope git_stash<CR>', desc = 'Git stash' },
  {
    '<leader>fgs',
    function()
      local opts = {}
      local top_level = vim.fn.system('git rev-parse --show-toplevel')

      if top_level ~= vim.fn.expand('~') then
        opts = {
          expand_dir = false -- if editing the dotfiles repo, do not show untracked files to avoid timeout
        }
      end

      require('telescope.builtin').git_status(opts)
    end,
    desc = 'Git status',
  },

  -- LSP operations
  { '<leader>l', group = 'Telescope (LSP)' },
  { '<leader>ls',  '<Cmd>Telescope lsp_document_symbols<CR>',          desc = 'Document symbols' },
  { '<leader>lr',  '<Cmd>Telescope lsp_references<CR>',                desc = 'References' },
  { '<leader>ld',  '<Cmd>Telescope lsp_definitions<CR>',               desc = 'Definitions' },
  { '<C-]>',       '<Cmd>Telescope lsp_definitions<CR>',               desc = 'Definitions' },
  { '<leader>lt',  '<Cmd>Telescope lsp_type_definitions<CR>',          desc = 'Typedefs' },
  { '<leader>lw', group = 'Workspace' },
  { '<leader>lws', '<Cmd>Telescope lsp_dynamic_workspace_symbols<CR>', desc = 'Workspace symbols' },
  -- { "<leader>lca", "<Cmd>FzfLua lsp_code_actions<CR>",           desc = "Code actions" },

  {
    '<C-e>',
    function()
      require('telescope.builtin').symbols { sources = { 'emoji', 'gitmoji' } }
    end,
    desc = 'Workspace symbols',
    mode = 'i',
    icon = '󰞅'
  },
}

return {
  'nvim-telescope/telescope.nvim',
  version = false, -- telescope did only one release, so use HEAD for now
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope-symbols.nvim', -- Provides its users with the ability of picking symbols and insert them at point.
    'tsakirist/telescope-lazy.nvim', -- Telescope extension that provides handy functionality about plugins installed via lazy.nvim
    'davvid/telescope-git-grep.nvim', -- Telescope extension for searching using "git grep"
    {
      'nvim-telescope/telescope-fzf-native.nvim', -- FZF sorter for telescope written in c
      build = 'make',
    },
  },
  cmd = 'Telescope',
  init = function()
    require('which-key').add(keys)

    local config = require('config')
    local function set_hl(name, attr)
      vim.api.nvim_set_hl(0, name, attr)
    end
    set_hl('TelescopeNormal', { link = 'NormalFloat' })
    set_hl('TelescopeBorder', { link = 'FloatBorder' })
    set_hl('TelescopeTitle', { fg = config.theme.colors.green })
    set_hl('TelescopePromptTitle', { fg = config.theme.colors.orange })
    set_hl('TelescopePromptBorder', { bg = config.theme.colors.dark0, fg = config.theme.colors.orange })
  end,
  opts = {
    defaults = {
      layout_strategy = 'vertical',
      layout_config = {
        vertical = { width = 0.7 },
      },
      mappings = {
        i = {
          -- map actions.which_key to <C-h> (default: <C-/>)
          -- actions.which_key shows the mappings for your picker,
          -- e.g. git_{create, delete, ...}_branch for the git_branches picker
          ['<C-h>'] = 'which_key',
          ['<Esc>'] = 'close', -- directly close on Escape
          ['<c-t>'] = function(...)
            return require('trouble.sources.telescope').open(...)
          end,
          ['<C-g>'] = function(prompt_bufnr)
            -- Use nvim-window-picker to choose the window by dynamically attaching a function
            local action_set = require('telescope.actions.set')
            local action_state = require('telescope.actions.state')

            local picker = action_state.get_current_picker(prompt_bufnr)
            picker.get_selection_window = function(picker, entry)
              local picked_window_id = require('window-picker').pick_window() or vim.api.nvim_get_current_win()
              -- Unbind after using so next instance of the picker acts normally
              picker.get_selection_window = nil
              return picked_window_id
            end

            return action_set.edit(prompt_bufnr, 'edit')
          end,
        },
      },
    },
    extensions = {
      fzf = {},
      git_grep = {},
      lazy = {},
    },
  },
}

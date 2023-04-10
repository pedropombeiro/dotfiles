-- Telescope (https://github.com/nvim-telescope/telescope.nvim)
--  Find, Filter, Preview, Pick. All lua, all the time.

---@format disable-next
local keys = {
  -- File operations
  { '<leader>ff',    '<Cmd>Telescope find_files<CR>', desc = 'Files' },
  { '<leader>fr',    '<Cmd>Telescope live_grep<CR>',  desc = 'Live grep (rg)' },
  { '<leader>fF',    '<Cmd>Telescope resume<CR>',     desc = 'Resume last Telescope command/query' },
  { '<leader><Tab>', '<Cmd>Telescope keymaps<CR>',    desc = 'Keymaps' },
  { '<leader>fb',    '<Cmd>Telescope buffers<CR>',    desc = 'Buffers' },
  {
    '<leader>fc',
    function()
      require('telescope').load_extension('themes')
      vim.cmd [[Telescope themes]]
    end,
    desc = 'Colorschemes'
  },
  { '<leader>fH',  '<Cmd>Telescope highlights<CR>',      desc = 'Highlight groups' },
  { '<leader>fK',  '<Cmd>Telescope man_pages<CR>',       desc = 'Man pages' },
  { '<leader>fl',  '<Cmd>Telescope loclist<CR>',         desc = 'Location list' },
  { '<leader>fq',  '<Cmd>Telescope quickfix<CR>',        desc = 'Quickfix list' },
  { '<leader>fT',  '<Cmd>Telescope filetypes<CR>',       desc = 'Filetypes' },
  { '<leader>fh',  '<Cmd>Telescope oldfiles<CR>',        desc = 'Old files' },
  { '<leader>f:',  '<Cmd>Telescope command_history<CR>', desc = 'Command history' },
  { '<leader>f/',  '<Cmd>Telescope search_history<CR>',  desc = 'Search history' },
  { '<leader>f`',  '<Cmd>Telescope marks<CR>',           desc = 'Marks' },
  { "<leader>f'",  '<Cmd>Telescope marks<CR>',           desc = 'Marks' },
  { '<leader>f.',  '<Cmd>Telescope jumplist<CR>',        desc = 'Jump list' },
  { '<leader>f@',  '<Cmd>Telescope registers<CR>',       desc = 'Registers' },
  { '<leader>fO',  '<Cmd>Telescope vim_options<CR>',     desc = 'Vim options' },
  { '<leader>fs',  '<Cmd>Telescope spell_suggest<CR>',   desc = 'Spelling suggestions' },
  { '<leader>fp',  '<Cmd>Telescope lazy<CR>',            desc = 'Plugins' },

  -- Git operations
  { '<leader>fgb', '<Cmd>Telescope git_branches<CR>',    desc = 'Git branches' },
  { '<leader>fgc', '<Cmd>Telescope git_commits<CR>',     desc = 'Git commits' },
  { '<leader>fgC', '<Cmd>Telescope git_bcommits<CR>',    desc = 'Git commits (buffer)' },
  {
    '<leader>fgg',
    function()
      local function is_git_repo()
        vim.fn.system('git rev-parse --is-inside-work-tree')

        return vim.v.shell_error == 0
      end

      local opts = {}

      if is_git_repo() then
        opts = {
          prompt_title = 'Git grep',
          vimgrep_arguments = { 'git', 'grep', '--line-number', '--column' },
        }
      end

      require('telescope.builtin').live_grep(opts)
    end,
    desc = 'Git grep'
  },
  { '<leader>fgf', '<Cmd>Telescope git_files<CR>',                     desc = 'Git files' },
  { '<leader>fgs', '<Cmd>Telescope git_status<CR>',                    desc = 'Git status' },
  { '<leader>fgS', '<Cmd>Telescope git_stash<CR>',                     desc = 'Git stash' },

  -- LSP operations
  { '<leader>ls',  '<Cmd>Telescope lsp_document_symbols<CR>',          desc = 'Document symbols' },
  { '<leader>lr',  '<Cmd>Telescope lsp_references<CR>',                desc = 'References' },
  { '<leader>ld',  '<Cmd>Telescope lsp_definitions<CR>',               desc = 'Definitions' },
  { '<C-]>',       '<Cmd>Telescope lsp_definitions<CR>',               desc = 'Definitions' },
  { '<leader>lt',  '<Cmd>Telescope lsp_type_definitions<CR>',          desc = 'Typedefs' },
  { '<leader>lws', '<Cmd>Telescope lsp_dynamic_workspace_symbols<CR>', desc = 'Workspace symbols' },
  -- { "<leader>lca", "<Cmd>FzfLua lsp_code_actions<CR>",           desc = "Code actions" },

  {
    '<C-e>',
    function()
      require('telescope.builtin').symbols { sources = { 'emoji', 'gitmoji' } }
    end,
    desc = 'Workspace symbols',
    mode = { 'i' }
  },
}

return {
  {
    'nvim-telescope/telescope.nvim',
    version = false, -- telescope did only one release, so use HEAD for now
    dependencies = {
      'nvim-lua/plenary.nvim',
      'tsakirist/telescope-lazy.nvim',              -- Telescope extension that provides handy functionality about plugins installed via lazy.nvim
      'nvim-telescope/telescope-symbols.nvim',      -- Provides its users with the ability of picking symbols and insert them at point.
      {
        'nvim-telescope/telescope-fzf-native.nvim', -- FZF sorter for telescope written in c
        build = 'make'
      }
    },
    keys = keys,
    init = function()
      local m = require('mapx')

      m.nname('<leader>f', 'Telescope')
      m.nname('<leader>fg', 'Telescope (Git)')
      m.nname('<leader>l', 'Telescope (LSP)')
      m.nname('<leader>lc', 'Telescope (LSP code actions)')
    end,
    opts = {
      defaults = {
        layout_strategy = 'vertical',
        layout_config = {
          vertical = { width = 0.7 }
        },
        mappings = {
          i = {
            -- map actions.which_key to <C-h> (default: <C-/>)
            -- actions.which_key shows the mappings for your picker,
            -- e.g. git_{create, delete, ...}_branch for the git_branches picker
            ['<C-h>'] = 'which_key',
            ['<Esc>'] = 'close', -- directly close on Escape
            ['<c-t>'] = function(...)
              return require('trouble.providers.telescope').open_with_trouble(...)
            end,
          }
        }
      }
    },
    config = function(_, opts)
      local config = require('config')
      local function set_hl(name, attr)
        vim.api.nvim_set_hl(0, name, attr)
      end
      set_hl('TelescopeTitle', { fg = config.theme.colors.green })
      set_hl('TelescopePromptTitle', { fg = config.theme.colors.dark_orange })
      set_hl('TelescopePromptBorder', { fg = config.theme.colors.dark_orange })

      require('telescope').setup(opts)

      require('telescope').load_extension 'fzf'
      require('telescope').load_extension 'lazy'
    end
  }
}

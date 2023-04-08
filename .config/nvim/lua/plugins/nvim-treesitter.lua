--  The goal of nvim-treesitter is both to provide a simple and easy way to use the interface for tree-sitter in Neovim
--    and to provide some basic functionality such as highlighting based on it:

return {
  {
    'nvim-treesitter/nvim-treesitter-textobjects', -- Syntax aware text-objects, select, move, swap, and peek support.
    event = 'BufReadPre',
  },

  {
    'nvim-treesitter/nvim-treesitter-context', -- Show code context
    event = 'BufReadPre',
    config = function()
      ---@diagnostic disable-next-line: undefined-field
      local colors = require('config').theme.colors

      require('treesitter-context').setup()

      vim.api.nvim_set_hl(0, 'TreesitterContextBottom', { underline = true, sp = colors.bg0_s })
    end,
  },

  {
    'nvim-treesitter/nvim-treesitter',
    event = 'BufReadPost',
    dependencies = {
      {
        'RRethy/nvim-treesitter-endwise', --- Wisely add 'end' in Ruby, Vimscript, Lua, etc.
        event = 'InsertEnter'
      },
      {
        'JoosepAlviste/nvim-ts-context-commentstring', -- Neovim treesitter plugin for setting the commentstring based on the cursor location in a file.
        event = 'InsertEnter'
      },
      'HiPhish/nvim-ts-rainbow2', -- Rainbow delimiters for Neovim through Tree-sitter
    },
    build = function()
      local ts_update = require('nvim-treesitter.install').update({ with_sync = true })
      ts_update()
    end,
    config = function()
      local opts = {
        -- A list of parser names, or "all"
        ensure_installed = {
          'bash',
          'diff',
          'dockerfile',
          'git_rebase',
          'gitignore',
          'go',
          'gomod',
          'json',
          'vimdoc',
          'html',
          'lua',
          'make',
          'markdown',
          'markdown_inline',
          'python',
          'regex',
          'ruby',
          'sql',
          'toml',
          'vim',
          'yaml'
        },
        -- Install parsers synchronously (only applied to `ensure_installed`)
        sync_install = false,
        -- Automatically install missing parsers when entering buffer
        -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
        auto_install = false,
        -- List of parsers to ignore installing (for "all")
        ignore_install = {
          'java',
          'javascript'
        },
        endwise = {
          enable = true,
        },
        rainbow = {
          enable = true,
          -- Which query to use for finding delimiters
          query = 'rainbow-parens',
          -- Highlight the entire buffer all at once
          strategy = require 'ts-rainbow'.strategy.global,
        },
        context_commentstring = { enable = true, enable_autocmd = false },
        highlight = {
          -- `false` will disable the whole extension
          enable = true,
          -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
          -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
          -- Using this option may slow down your editor, and you may see some duplicate highlights.
          -- Instead of true it can also be a list of languages
          additional_vim_regex_highlighting = false,
          disable = function(lang, bufnr) -- Disable in large buffers
            if lang == 'markdown' then
              return true
            end

            return vim.api.nvim_buf_line_count(bufnr) > 5000
          end,
          -- additional_vim_regex_highlighting = true,
        },
        indent = { enable = true, disable = { 'python', 'css', 'rust' } },
        autotag = {
          enable = true,
          disable = { 'xml', 'markdown' },
        },
        textobjects = {
          select = {
            enable = true,
            -- Automatically jump forward to textobj, similar to targets.vim
            lookahead = true,
            keymaps = {
              -- You can use the capture groups defined in textobjects.scm
              ['af'] = '@function.outer',
              ['if'] = '@function.inner',
              ['ac'] = '@class.outer',
              ['ic'] = '@class.inner'
            }
          },
          move = {
            enable = true,
            set_jumps = true,
            goto_next_start = {
              [']m'] = '@function.outer',
              [']]'] = '@class.outer'
            },
            goto_next_end = {
              [']M'] = '@function.outer',
              [']['] = '@class.outer'
            },
            goto_previous_start = {
              ['[m'] = '@function.outer',
              ['[['] = '@class.outer'
            },
            goto_previous_end = {
              ['[M'] = '@function.outer',
              ['[]'] = '@class.outer'
            }
          },
          swap = {
            enable = true,
            swap_next = {
              ['<leader>.'] = '@parameter.inner',
            },
            swap_previous = {
              ['<leader>,'] = '@parameter.inner',
            },
          },
        },
      }

      require('nvim-treesitter.configs').setup(opts)
    end
  }
}

-- nvim-cmp (https://github.com/hrsh7th/nvim-cmp)
--  A completion plugin for neovim coded in Lua.

return {
  'hrsh7th/nvim-cmp',
  event = 'InsertEnter',
  dependencies = {
    'hrsh7th/cmp-buffer',                                 -- nvim-cmp source for buffer words
    'hrsh7th/cmp-nvim-lsp',                               -- nvim-cmp source for neovim builtin LSP client
    'hrsh7th/cmp-nvim-lua',                               -- nvim-cmp source for nvim lua
    'hrsh7th/cmp-path',                                   -- nvim-cmp source for path
    'hrsh7th/cmp-vsnip',                                  -- nvim-cmp source for vim-vsnip
    'hrsh7th/cmp-nvim-lsp-signature-help',                -- nvim-cmp source for displaying function signatures with the current parameter emphasized
    'hrsh7th/cmp-cmdline',                                -- nvim-cmp source for vim's cmdline
    { 'hrsh7th/vim-vsnip',                 lazy = true }, -- Snippet plugin for vim/nvim that supports LSP/VSCode's snippet format.
    { 'williamboman/mason-lspconfig.nvim', lazy = true },
    {
      'onsails/lspkind.nvim',                 -- vscode-like pictograms for neovim lsp completion items
      dependencies = 'mortepau/codicons.nvim' -- A plugin simplifying the task of working with VS Code codicons in Neovim
    },
    {
      'rafamadriz/friendly-snippets', -- Set of preconfigured snippets for different languages.
      ft = { 'dockerfile', 'go', 'lua', 'ruby' },
      init = function()
        vim.g.vsnip_filetypes = {
          ruby = { 'rails' }
        }
      end
    },
  },
  opts = function()
    local cmp = require('cmp')
    local kinds = require('cmp.types').lsp.CompletionItemKind

    cmp.setup({
      performance = {
        debounce = 50,
        throttle = 10,
      },
      preselect = cmp.PreselectMode.None,
      snippet = {
        -- REQUIRED - you must specify a snippet engine
        expand = function(args)
          vim.fn['vsnip#anonymous'](args.body) -- For `vsnip` users.
        end,
      },
      view = {
        max_height = 20,
      },
      window = {
        -- completion = cmp.config.window.bordered(),
        -- documentation = cmp.config.window.bordered(),
      },
      formatting = {
        format = require('lspkind').cmp_format({ preset = 'codicons' })
      },
      mapping = cmp.mapping.preset.insert({
        ['<C-n>']     = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
        ['<C-p>']     = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
        ['<C-b>']     = cmp.mapping.scroll_docs(-4),
        ['<C-f>']     = cmp.mapping.scroll_docs(4),
        ['<C-Space>'] = cmp.mapping.complete(),
        ['<C-e>']     = cmp.mapping({
          i = cmp.mapping.abort(),
          c = cmp.mapping.close(),
        }),
        ['<CR>']      = cmp.mapping.confirm({
          behavior = cmp.ConfirmBehavior.Replace,
          select = false,
        }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
      }),
      sources = cmp.config.sources({
        {
          name = 'nvim_lsp',
          priority = 80,
          group_index = 1,
          entry_filter = function(entry, context)
            local kind = entry:get_kind()
            local line = context.cursor_line
            local col = context.cursor.col
            local chars_before = line:sub(col - 4, col - 1)

            if chars_before:find('%.') or chars_before:find('%:') then
              -- If any previous 4 characters contains a "." or ":"
              return kind == kinds.Method or kind == kinds.Function or kinds.Field
            elseif line:match('^%s*%w*$') then
              -- text in the new line
              return kind == kinds.Function or kind == kinds.Variable
            end
            return true
          end
        },
        { name = 'nvim_lua', priority = 80, group_index = 1 },
        { name = 'vsnip',    priority = 10, group_index = 2 }, -- For vsnip users.
        { name = 'path',     priority = 40, max_item_count = 10, group_index = 5 },
        { name = 'git' },
        {
          name = 'buffer',
          priority = 5,
          keyword_length = 3,
          max_item_count = 5,
          group_index = 5,
          option = {
            get_bufnrs = function()
              return vim.api.nvim_list_bufs()
            end,
          },
        },
        { name = 'cmdline' },
        { name = 'path' },
        { name = 'nvim_lsp_signature_help' },
      }),
      experimental = {
        ghost_text = {
          hl_group = 'LspCodeLens',
        },
      },
    })

    cmp.setup.filetype('gitcommit', {
      sources = {
        { name = 'buffer' },
      }
    })

    cmp.setup.cmdline({ '/', '?' }, {
      sources = {
        { name = 'buffer' }
      }
    })

    cmp.setup.cmdline(':', {
      sources = {
        { name = 'cmdline' }
      }
    })
  end
}

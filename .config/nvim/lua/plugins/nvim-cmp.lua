-- nvim-cmp (https://github.com/hrsh7th/nvim-cmp)
--  A completion plugin for neovim coded in Lua.

local has_words_before = function()
  unpack = unpack or table.unpack
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match('%s') == nil
end

return {
  -- auto completion
  {
    'hrsh7th/nvim-cmp',
    version = false, -- last release is way too old
    event = { 'InsertEnter', 'CmdlineEnter' },
    dependencies = {
      'hrsh7th/cmp-buffer', -- nvim-cmp source for buffer words
      'hrsh7th/cmp-calc', -- nvim-cmp source for math calculation
      'hrsh7th/cmp-nvim-lsp', -- nvim-cmp source for neovim builtin LSP client
      'hrsh7th/cmp-nvim-lua', -- nvim-cmp source for nvim lua
      'hrsh7th/cmp-path', -- nvim-cmp source for path
      'rafamadriz/friendly-snippets',
      { 'garymjr/nvim-snippets', opts = { friendly_snippets = true } },
      'hrsh7th/cmp-nvim-lsp-signature-help', -- nvim-cmp source for displaying function signatures with the current parameter emphasized
      {
        'williamboman/mason-lspconfig.nvim',
        enabled = function()
          return vim.fn.has('mac') == 1
        end,
        lazy = true,
      },
      'onsails/lspkind.nvim', -- vscode-like pictograms for neovim lsp completion items
      {
        'petertriho/cmp-git', -- Git source for nvim-cmp
        dependencies = 'nvim-lua/plenary.nvim',
      },
    },
    config = function()
      local cmp = require('cmp')
      local compare = require('cmp.config.compare')
      local cmp_kinds = require('config').ui.icons.kinds
      local types = require('cmp.types')
      local kinds = types.lsp.CompletionItemKind

      ---@type table<integer, integer>
      local modified_priority = {
        [types.lsp.CompletionItemKind.Variable] = types.lsp.CompletionItemKind.Method,
        [types.lsp.CompletionItemKind.Property] = 0, -- top
        [types.lsp.CompletionItemKind.Keyword] = 0, -- top
        [types.lsp.CompletionItemKind.Snippet] = 1, -- top
        [types.lsp.CompletionItemKind.Text] = 100, -- bottom
      }
      ---@param kind integer: kind of completion entry
      local function modified_kind(kind)
        return modified_priority[kind] or kind
      end

      cmp.setup({
        performance = {
          debounce = 50,
          throttle = 10,
          fetching_timeout = 500,
          confirm_resolve_timeout = 80,
          async_budget = 1,
          max_view_entries = 200,
        },

        preselect = cmp.PreselectMode.None,

        snippet = {
          -- REQUIRED - you must specify a snippet engine
          expand = function(args)
            vim.snippet.expand(args.body)
          end,
        },

        view = {
          max_height = 20,
        },

        window = {
          documentation = cmp.config.window.bordered(),
        },

        formatting = {
          expandable_indicator = true,
          fields = { 'kind', 'abbr', 'menu' },
          format = function(entry, vim_item)
            vim_item.menu = '    (' .. (vim_item.kind or '') .. ')'
            if vim.tbl_contains({ 'path' }, entry.source.name) then
              local icon, hl_group = require('nvim-web-devicons').get_icon(entry:get_completion_item().label)
              if icon then
                vim_item.kind = ' ' .. (icon or '')
                vim_item.kind_hl_group = hl_group
                return vim_item
              end
            end

            vim_item.kind = ' ' .. (cmp_kinds[vim_item.kind] or '')

            return vim_item
          end,
        },

        mapping = cmp.mapping.preset.insert({
          ['<C-n>'] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
          ['<C-p>'] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
          ['<C-b>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<C-e>'] = cmp.mapping({
            i = cmp.mapping.abort(),
            c = cmp.mapping.close(),
          }),
          ['<Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
              -- You could replace the expand_or_jumpable() calls with expand_or_locally_jumpable()
              -- that way you will only jump inside the snippet region
            elseif vim.snippet.active({ direction = 1 }) then
              vim.schedule(function()
                vim.snippet.jump(1)
              end)
            elseif has_words_before() then
              cmp.complete()
            else
              fallback()
            end
          end, { 'i', 's' }),
          ['<S-Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif vim.snippet.active({ direction = -1 }) then
              vim.schedule(function()
                vim.snippet.jump(-1)
              end)
            else
              fallback()
            end
          end, { 'i', 's' }),
          ['<CR>'] = cmp.mapping.confirm({
            behavior = cmp.ConfirmBehavior.Replace,
            select = true,
          }),
        }),

        sorting = {
          priority_weight = 1,
          -- https://github.com/hrsh7th/nvim-cmp/blob/main/lua/cmp/config/compare.lua
          comparators = {
            compare.offset,
            compare.exact,
            compare.recently_used,
            function(entry1, entry2) -- sort by compare kind (Variable, Function etc)
              local kind1 = modified_kind(entry1:get_kind())
              local kind2 = modified_kind(entry2:get_kind())
              if kind1 ~= kind2 then
                return kind1 - kind2 < 0
              end
            end,
            function(entry1, entry2) -- score by lsp, if available
              local t1 = entry1.completion_item.sortText
              local t2 = entry2.completion_item.sortText
              if t1 ~= nil and t2 ~= nil and t1 ~= t2 then
                return t1 < t2
              end
            end,
            compare.score,
            compare.order,
            function(entry1, entry2) -- sort by length ignoring "=~"
              local len1 = string.len(string.gsub(entry1.completion_item.label, '[=~()_]', ''))
              local len2 = string.len(string.gsub(entry2.completion_item.label, '[=~()_]', ''))
              if len1 ~= len2 then
                return len1 - len2 < 0
              end
            end,
          },
        },

        sources = cmp.config.sources({
          { name = 'calc', priority = 4 },
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
          { name = 'snippets', priority = 10, max_item_count = 3, group_index = 2 },
          { name = 'path', priority = 40, max_item_count = 10, group_index = 5 },
          { name = 'nvim_lua', priority = 80, group_index = 1 },
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
              end
              return true
            end,
          },
          { name = 'nvim_lsp_signature_help' },
        }),

        experimental = {
          ghost_text = {
            hl_group = 'LspCodeLens',
          },
        },
      })

      cmp.setup.filetype('gitcommit', {
        sources = cmp.config.sources({
          { name = 'git' }, -- You can specify the `git` source if [you were installed it](https://github.com/petertriho/cmp-git).
        }, {
          { name = 'buffer' },
        }),
      })
    end,
  },
}

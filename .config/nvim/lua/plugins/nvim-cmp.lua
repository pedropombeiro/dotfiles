-- nvim-cmp (https://github.com/hrsh7th/nvim-cmp)
--  A completion plugin for neovim coded in Lua.

local has_words_before = function()
  unpack = unpack or table.unpack
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match('%s') == nil
end

return {
  -- snippets
  {
    'L3MON4D3/LuaSnip',
    event = { 'InsertEnter' },
    build = (not jit.os:find('Windows'))
        and "echo 'NOTE: jsregexp is optional, so not a big deal if it fails to build\n'; make install_jsregexp"
      or nil,
    dependencies = {
      'rafamadriz/friendly-snippets',
      config = function()
        require('luasnip.loaders.from_vscode').lazy_load()
      end,
    },
    opts = {
      history = true,
      delete_check_events = 'TextChanged',
    },
  },

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
      'saadparwaiz1/cmp_luasnip', -- nvim-cmp source for LuaSnip
      'hrsh7th/cmp-nvim-lsp-signature-help', -- nvim-cmp source for displaying function signatures with the current parameter emphasized
      { 'williamboman/mason-lspconfig.nvim', lazy = true },
      {
        'onsails/lspkind.nvim', -- vscode-like pictograms for neovim lsp completion items
        dependencies = 'mortepau/codicons.nvim', -- A plugin simplifying the task of working with VS Code codicons in Neovim
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
            require('luasnip').lsp_expand(args.body)
          end,
        },
        view = {
          max_height = 20,
        },
        formatting = {
          format = require('lspkind').cmp_format({ preset = 'codicons' }),
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
            local luasnip = require('luasnip')

            if cmp.visible() then
              cmp.select_next_item()
              -- You could replace the expand_or_jumpable() calls with expand_or_locally_jumpable()
              -- that way you will only jump inside the snippet region
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            elseif has_words_before() then
              cmp.complete()
            else
              fallback()
            end
          end, { 'i', 's' }),
          ['<S-Tab>'] = cmp.mapping(function(fallback)
            local luasnip = require('luasnip')

            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { 'i', 's' }),

          ['<CR>'] = cmp.mapping.confirm({
            behavior = cmp.ConfirmBehavior.Replace,
            select = true,
          }),
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
            end,
          },
          { name = 'nvim_lua', priority = 80, group_index = 1 },
          { name = 'luasnip', priority = 10, group_index = 2 }, -- For luasnip users.
          { name = 'path', priority = 40, max_item_count = 10, group_index = 5 },
          { name = 'calc', priority = 50 },
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
        },
      })
    end,
  },
}

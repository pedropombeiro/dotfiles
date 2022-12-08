-- nvim-cmp (https://github.com/hrsh7th/nvim-cmp)
--  A completion plugin for neovim coded in Lua.

vim.o.completeopt = "menu,menuone,noselect"

-- Set up nvim-cmp.
local cmp = require("cmp")

cmp.setup({
  snippet = {
    -- REQUIRED - you must specify a snippet engine
    expand = function(args)
      require("luasnip").lsp_expand(args.body) -- For `luasnip` users.
    end,
  },
  window = {
    -- completion = cmp.config.window.bordered(),
    -- documentation = cmp.config.window.bordered(),
  },
  formatting = {
    format = require("lspkind").cmp_format({ preset = "codicons" })
  },
  mapping = cmp.mapping.preset.insert({
    ["<C-b>"]     = cmp.mapping.scroll_docs(-4),
    ["<C-f>"]     = cmp.mapping.scroll_docs(4),
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<C-e>"]     = cmp.mapping.abort(),
    ["<CR>"]      = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
  }),
  sources = cmp.config.sources({
    { name = "nvim_lsp" },
    { name = "luasnip" }, -- For luasnip users.
  }, {
    { name = "buffer" },
    { name = "cmdline" },
    { name = "path" },
  }),
})

cmp.setup.filetype("gitcommit", {
  sources = {
    { name = "buffer" },
  }
})

cmp.setup.cmdline({ "/", "?" }, {
  sources = {
    { name = "buffer" }
  }
})

cmp.setup.cmdline(":", {
  sources = {
    { name = "cmdline" }
  }
})

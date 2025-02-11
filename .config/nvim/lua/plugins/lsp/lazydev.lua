-- lazydev.nvim (https://github.com/folke/lazydev.nvim)
--   Faster LuaLS setup for Neovim

return {
  {
    "folke/lazydev.nvim",
    lazy = true,
    ft = { "lua" },
    opts = {
      library = {
        -- See the configuration section for more details
        -- Load luvit types when the `vim.uv` word is found
        { path = "luvit-meta/library", words = { "vim%.uv" } },
        { path = "snacks.nvim", words = { "Snacks" } },
      },
    },
  },
  { "Bilal2453/luvit-meta", lazy = true }, -- optional `vim.uv` typings
}

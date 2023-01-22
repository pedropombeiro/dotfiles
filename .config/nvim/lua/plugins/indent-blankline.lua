-- mapx (https://github.com/b0o/mapx.nvim)
--  🗺 A better way to create key mappings in Neovim

return {
  "lukas-reineke/indent-blankline.nvim", -- Indent guides for Neovim
  event = "BufReadPost",
  opts = {
    char = "│",
    filetype_exclude = { "help", "alpha", "dashboard", "neo-tree", "Trouble", "lazy" },
    show_trailing_blankline_indent = false,
    show_current_context = false,
  },
}

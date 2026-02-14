-- mini.trailspace (https://github.com/echasnovski/mini.trailspace)
--  Neovim Lua plugin to manage trailspace (highlight and remove). Part of 'mini.nvim' library.

return {
  "nvim-mini/mini.trailspace",
  version = "*",
  event = { "BufReadPre", "BufNewFile" },
  opts = {},
}

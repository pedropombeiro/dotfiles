-- mini.trailspace (https://github.com/echasnovski/mini.trailspace)
--  Neovim Lua plugin to manage trailspace (highlight and remove). Part of 'mini.nvim' library.

return {
  "echasnovski/mini.trailspace",
  version = "*",
  event = { "BufReadPre", "BufNewFile" },
  opts = {},
}

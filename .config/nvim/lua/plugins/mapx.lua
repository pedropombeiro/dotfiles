-- mapx (https://github.com/b0o/mapx.nvim)
--  🗺 A better way to create key mappings in Neovim

return {
  "b0o/mapx.nvim",
  lazy = true,
  dependencies = "folke/which-key.nvim",
  opts = { global = "force", whichkey = true }
}

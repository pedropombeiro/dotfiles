-- mapx (https://github.com/b0o/mapx.nvim)
--  🗺 A better way to create key mappings in Neovim

return {
  "b0o/mapx.nvim",
  config = function()
    require("mapx").setup { global = "force", whichkey = true }
  end
}

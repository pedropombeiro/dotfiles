-- Ranger.vim (https://github.com/francoiscabrol/ranger.vim)
--  Ranger integration in vim and neovim

return {
  "francoiscabrol/ranger.vim",
  cmd = { "Ranger", "RangerWorkingDirectory" },
  dependencies = "rbgrouleff/bclose.vim", -- The BClose Vim plugin for deleting a buffer without closing the window
  config = function()
    vim.g.ranger_map_keys = 0
  end
}

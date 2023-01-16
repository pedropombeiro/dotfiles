-- urlview.nvim (https://github.com/axieax/urlview.nvim)
-- 🔎 Neovim plugin for viewing all the URLs in a buffer

require("urlview").setup({
  default_action = "system",
  jump = {
    prev = "[U",
    next = "]U",
  },
})

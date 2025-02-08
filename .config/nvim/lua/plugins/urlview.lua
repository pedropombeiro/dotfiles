-- urlview.nvim (https://github.com/axieax/urlview.nvim)
-- 🔎 Neovim plugin for viewing all the URLs in a buffer

return {
  "axieax/urlview.nvim",
  cmd = "UrlView",
  init = function()
    local function open_buffer_urlview()
      if vim.fn.expand("%:p") == vim.fn.stdpath("config") .. "/lua/plugins.lua" then
        vim.cmd([[UrlView lazy]])
      else
        vim.cmd([[UrlView]])
      end
    end

    require("which-key").add({
      "<leader>fu",
      open_buffer_urlview,
      icon = "󰖟",
      silent = true,
      remap = true,
      desc = "List buffer URLs",
    })
  end,
  opts = {
    default_action = "system",
    jump = {
      prev = "[U",
      next = "]U",
    },
  },
}

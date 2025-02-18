-- urlview.nvim (https://github.com/axieax/urlview.nvim)
-- 🔎 Neovim plugin for viewing all the URLs in a buffer

local function open_buffer_urlview()
  if vim.fn.expand("%:p") == vim.fn.stdpath("config") .. "/lua/plugins.lua" then
    vim.cmd([[UrlView lazy]])
  else
    vim.cmd([[UrlView]])
  end
end

return {
  "axieax/urlview.nvim",
  cmd = "UrlView",
  opts = {
    default_action = "system",
    jump = {
      prev = "[U",
      next = "]U",
    },
  },
  specs = {
    {
      "folke/which-key.nvim",
      opts = {
        ---@module "which-key"
        ---@type wk.Spec
        spec = {
          { "<leader>fu", open_buffer_urlview, icon = "󰖟", silent = true, remap = true, desc = "List buffer URLs" },
        },
      },
    },
  },
}

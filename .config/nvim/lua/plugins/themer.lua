-- themer.lua (https://github.com/themercorp/themer.lua)
--  A simple, minimal highlighter plugin for neovim

local theme = vim.env.NVIM_THEME -- defined in ~/.shellrc/rc.d/_theme.sh
if theme == nil then
  local config = require("config")
  ---@diagnostic disable-next-line: undefined-field
  theme = config.theme.name
end

return {
  "themercorp/themer.lua",
  lazy = false,
  priority = 1000, -- make sure to load this before all the other start plugins
  opts = {
    colorscheme = theme,
    plugins = {
      treesitter = true,
      indentline = true,
      barbar = false,
      bufferline = false,
      cmp = true,
      gitsigns = true,
      lsp = true,
      telescope = false,
    },
  }
}

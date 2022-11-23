-- themer.lua (https://github.com/themercorp/themer.lua)
--  A simple, minimal highlighter plugin for neovim

local theme = vim.env.NVIM_THEME -- defined in ~/.shellrc/rc.d/theme.sh
if theme == nil then
  theme = "gruvbox"
end

require("themer").setup({
  colorscheme = theme,
  langs = {
    html = true,
    md   = true,
  },
})

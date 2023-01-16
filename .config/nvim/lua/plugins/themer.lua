-- themer.lua (https://github.com/themercorp/themer.lua)
--  A simple, minimal highlighter plugin for neovim

local theme = vim.env.NVIM_THEME -- defined in ~/.shellrc/rc.d/_theme.sh
if theme == nil then
  theme = "gruvbox-material-dark-soft"
end

require("themer").setup({
  colorscheme = theme,
  langs = {
    html = true,
    md   = true,
  },
})

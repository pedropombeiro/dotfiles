-- themer.lua (https://github.com/themercorp/themer.lua)
--  A simple, minimal highlighter plugin for neovim

require("themer").setup({
  colorscheme = vim.env.NVIM_THEME, -- defined in ~/.shellrc/rc.d/theme.sh
  langs = {
    html = true,
    md   = true,
  },
})

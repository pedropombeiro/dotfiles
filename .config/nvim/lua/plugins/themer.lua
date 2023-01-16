-- themer.lua (https://github.com/themercorp/themer.lua)
--  A simple, minimal highlighter plugin for neovim

return {
  "themercorp/themer.lua",
  priority = 1000, -- make sure to load this before all the other start plugins
  config = function()
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
  end
}

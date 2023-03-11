-- themer.lua (https://github.com/themercorp/themer.lua)
--  A simple, minimal highlighter plugin for neovim

return {
  "themercorp/themer.lua",
  lazy = false,
  priority = 1000,                   -- make sure to load this before all the other start plugins
  opts = function()
    local theme = vim.env.NVIM_THEME -- defined in ~/.shellrc/rc.d/_theme.sh
    if theme == nil then
      local config = require("config")
      ---@diagnostic disable-next-line: undefined-field
      theme = config.theme.name
    end

    return {
      colorscheme = theme,
      plugins = {
        treesitter = true,
        indentline = true,
        barbar = false,
        bufferline = true,
        cmp = true,
        gitsigns = true,
        lsp = true,
        telescope = false,
      },
    }
  end
}

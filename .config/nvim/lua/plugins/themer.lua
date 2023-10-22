-- themer.lua (https://github.com/themercorp/themer.lua)
--  A simple, minimal highlighter plugin for neovim

return {
  'themercorp/themer.lua',
  lazy = false,
  priority = 1000,                   -- make sure to load this before all the other start plugins
  opts = function()
    local theme = vim.env.NVIM_THEME -- defined in ~/.shellrc/rc.d/_theme.sh
    if theme == nil then
      local config = require('config')
      ---@diagnostic disable-next-line: undefined-field
      theme = config.theme.name
    end

    if theme == 'gruvbox-material-dark-soft' then
      -- Some colors in the soft scheme need adjusting, in order to have an acceptable contrast
      local function define_highlights()
        vim.cmd [[
          highlight DiffAdd ctermbg=4 guibg=#32302f guifg=#8ec07c
          highlight DiffChange ctermbg=5 guibg=#012800
          highlight DiffDelete ctermfg=12 ctermbg=6 gui=bold guibg=#3c1f1e guifg=#fb4934
          highlight DiffText cterm=bold ctermbg=9 gui=bold guibg=#7daea3
        ]]
      end

      local augroup = vim.api.nvim_create_augroup('ThemerColorSchemeRefresh', { clear = true })
      vim.api.nvim_create_autocmd(
        { 'BufRead', 'BufNewFile' },
        {
          callback = define_highlights,
          group = augroup,
        })
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
        telescope = true,
      },
    }
  end
}

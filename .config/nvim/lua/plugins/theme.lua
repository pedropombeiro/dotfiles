-- gruvbox-flat (https://github.com/eddyekofo94/gruvbox-flat.nvim)
--  Another attempt of a flat Gruvbox theme for Neovim

return {
  'eddyekofo94/gruvbox-flat.nvim',
  lazy = false,
  priority = 1000, -- make sure to load this before all the other start plugins
  init = function()
    local theme = vim.env.NVIM_THEME -- defined in ~/.shellrc/rc.d/_theme.sh
    if theme == nil then
      local config = require('config')
      ---@diagnostic disable-next-line: undefined-field
      theme = config.theme.name
    end

    return theme == 'gruvbox-material-dark'
  end,
  config = function()
    local function set_hl(name, attr)
      vim.api.nvim_set_hl(0, name, attr)
    end

    local function initialize_theme()
      -- Change border for float windows (normally grey)
      set_hl('FloatBorder', { ctermfg = 109, fg = '#83a598' })
      set_hl('FloatermBorder', { link = 'FloatBorder' })
      set_hl('LspInfoBorder', { link = 'FloatBorder' })

      -- Change border for LSP elements, to make them more recognizable (same colors as the bat gruvbox theme)
      set_hl('@field', { ctermfg = 167, fg = '#fb4934' })
      set_hl('@constant', { ctermfg = 109, fg = '#83a598' })
      set_hl('@string', { ctermfg = 142, fg = '#b8bb26' })
    end

    local augroup = vim.api.nvim_create_augroup('ThemerColorSchemeRefresh', { clear = true })
    vim.api.nvim_create_autocmd('UIEnter', {
      callback = initialize_theme,
      group = augroup,
    })

    if vim.fn.has('termguicolors') then
      vim.opt.termguicolors = true
    end

    vim.g.gruvbox_flat_style = 'hard'

    vim.cmd('colorscheme gruvbox-flat')
  end,
}

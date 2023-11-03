-- gruvbox-material (https://github.com/sainnhe/gruvbox-material)
--  Gruvbox with Material Palette

return {
  'sainnhe/gruvbox-material',
  lazy = false,
  priority = 1000, -- make sure to load this before all the other start plugins
  config = function()
    local theme = vim.env.NVIM_THEME -- defined in ~/.shellrc/rc.d/_theme.sh
    if theme == nil then
      local config = require('config')
      ---@diagnostic disable-next-line: undefined-field
      theme = config.theme.name
    end

    if theme == 'gruvbox-material-dark' then
      local function define_highlights()
        vim.cmd([[
          " Change border for float windows (normally grey)
          highlight FloatBorder ctermfg=66 guifg=#458588

          " Change border for LSP elements, to make them more recognizable (same colors as the bat gruvbox theme)
          highlight @field    ctermfg=167 guifg=#fb4934
          highlight @constant ctermfg=109 guifg=#83a598
          highlight @string   ctermfg=142 guifg=#b8bb26
        ]])
      end

      local augroup = vim.api.nvim_create_augroup('ThemerColorSchemeRefresh', { clear = true })
      vim.api.nvim_create_autocmd('UIEnter', {
        callback = define_highlights,
        group = augroup,
      })

      vim.g.gruvbox_material_background = 'hard'
      vim.g.gruvbox_material_better_performance = 1
      vim.g.gruvbox_material_foreground = 'hard'
      vim.g.gruvbox_material_diagnostic_text_highlight = 1
      vim.g.gruvbox_material_diagnostic_virtual_text = 'highlighted'
      vim.g.gruvbox_material_enable_italic = 1
      vim.g.gruvbox_material_float_style = 'dim'

      if vim.fn.has('termguicolors') then
        vim.opt.termguicolors = true
      end

      vim.cmd('colorscheme gruvbox-material')
    end
  end,
}

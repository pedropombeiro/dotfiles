-- mini.trailspace (https://github.com/echasnovski/mini.trailspace)
--  Neovim Lua plugin to manage trailspace (highlight and remove). Part of 'mini.nvim' library.

return {
  'echasnovski/mini.trailspace',
  version = false,
  event = { 'BufReadPre', 'BufNewFile' },
  init = function()
    local function augroup(name)
      return vim.api.nvim_create_augroup('_' .. name, { clear = true })
    end

    vim.api.nvim_create_autocmd('FileType', {
      group = augroup('MiniCursorWordBuffers'),
      pattern = {
        'lazy',
        'neotest-output',
        'neotest-summary',
        'neotest-output-panel',
        'snacks_dashboard',
      },
      callback = function(event)
        vim.b[event.buf].minitrailspace_disable = true
        require('mini.trailspace').unhighlight()
      end,
    })
  end,
  opts = {},
}

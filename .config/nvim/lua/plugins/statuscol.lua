-- statuscol.nvim (https://github.com/luukvbaal/statuscol.nvim)
--  Status column plugin that provides a configurable 'statuscolumn' and click handlers.

local opts = function()
  local builtin = require('statuscol.builtin')
  -- stylua: ignore
  return {
    relculright = true,
    segments = {
      { text = { builtin.foldfunc },      click = 'v:lua.ScFa' },
      { text = { '%s' },                  click = 'v:lua.ScSa' },
      { text = { builtin.lnumfunc, ' ' }, click = 'v:lua.ScLa' }
    }
  }
end

return {
  'luukvbaal/statuscol.nvim',
  event = { 'BufRead', 'BufNewFile' },
  opts = opts,
}

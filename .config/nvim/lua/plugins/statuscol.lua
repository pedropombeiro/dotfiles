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

if vim.fn.has('nvim-0.10') == 1 then
  return {
    'luukvbaal/statuscol.nvim',
    event = { 'BufRead', 'BufNewFile' },
    opts = opts,
  }
else
  return {
    'luukvbaal/statuscol.nvim',
    commit = '51428469218c3b382cab793a2d53c72014627fbe', -- last commit that supports neovim 0.9
    pin = true,
    event = { 'BufRead', 'BufNewFile' },
    opts = opts,
  }
end

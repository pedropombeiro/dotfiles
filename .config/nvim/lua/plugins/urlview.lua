-- urlview.nvim (https://github.com/axieax/urlview.nvim)
-- 🔎 Neovim plugin for viewing all the URLs in a buffer

return {
  'axieax/urlview.nvim',
  cmd = 'UrlView',
  init = function()
    local urlview_augroup = vim.api.nvim_create_augroup('urlview', { clear = true })

    local function open_buffer_urlview()
      if vim.fn.expand('%:p') == vim.fn.stdpath('config') .. '/lua/plugins.lua' then
        vim.cmd([[UrlView lazy]])
      else
        vim.cmd([[UrlView]])
      end
    end

    vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
      pattern = '*',
      group = urlview_augroup,
      callback = function(ev)
        require('which-key').add({
          '<leader>fu',
          open_buffer_urlview,
          icon = '󰖟',
          silent = true,
          remap = true,
          desc = 'List buffer URLs',
          buffer = ev['buf'],
        })
      end,
    })
  end,
  opts = {
    default_action = 'system',
    jump = {
      prev = '[U',
      next = ']U',
    },
  },
}

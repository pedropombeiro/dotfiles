-- firenvim (https://github.com/glacambre/firenvim)
--  Embed Neovim in Chrome, Firefox & others.

return {
  'glacambre/firenvim',
  -- Lazy load firenvim
  -- Explanation: https://github.com/folke/lazy.nvim/discussions/463#discussioncomment-4819297
  cond = not not vim.g.started_by_firenvim,
  build = function()
    require('lazy').load({ plugins = 'firenvim', wait = true })
    vim.fn['firenvim#install'](0)
  end,
  init = function()
    -- Never takeover by default
    local localSettings = {
      ['.*'] = {
        cmdline = 'neovim',
        content = 'text',
        priority = 0,
        selector = 'textarea',
        takeover = 'never'
      },
      ['https?://mail.google.com/'] = { takeover = 'never', priority = 1 },
      ['https?://discord.com/'] = { takeover = 'never', priority = 1 },
    }

    vim.g.firenvim_config = {
      localSettings = localSettings
    }

    vim.opt.guifont = { 'MesloLGS Nerd Font', 'h22' }

    local firenvim_targets_augroup = vim.api.nvim_create_augroup('firenvim_targets', { clear = true })
    vim.api.nvim_create_autocmd('BufEnter', {
      pattern = {
        'gitlab.com_*.txt',
        'github.com_*.txt',
        'reddit.com_*.txt'
      },
      group = firenvim_targets_augroup,
      command = 'set filetype=markdown'
    })
    vim.api.nvim_create_autocmd('BufEnter', {
      pattern = 'build.particle.io_*.txt',
      group = firenvim_targets_augroup,
      command = 'set filetype=c'
    })
  end
}

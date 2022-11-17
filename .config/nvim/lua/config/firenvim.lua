-- firenvim (https://github.com/glacambre/firenvim)
--  Embed Neovim in Chrome, Firefox & others.

if vim.g.started_by_firenvim then
  -- Never takeover by default
  local localSettings = {
    [".*"] = {
      cmdline = "neovim",
      content = "text",
      priority = 0,
      selector = "textarea",
      takeover = "never"
    },
    ["https?://mail.google.com/"] = { takeover = "never", priority = 1 },
    ["https?://discord.com/"] = { takeover = "never", priority = 1 },
  }

  vim.g.firenvim_config = {
    localSettings = localSettings
  }

  vim.opt.guifont = { "MesloLGS Nerd Font", "h22" }

  vim.cmd([[
    augroup firenvim_targets
      au BufEnter gitlab.com_*.txt set filetype=markdown
      au BufEnter github.com_*.txt set filetype=markdown
      au BufEnter reddit.com_*.txt set filetype=markdown
      au BufEnter build.particle.io_*.txt set filetype=c
    augroup END
  ]])
end

-- mason.nvim (https://github.com/williamboman/mason.nvim)
--   Portable package manager for Neovim that runs everywhere Neovim runs. Easily install and manage LSP servers,
--   DAP servers, linters, and formatters.

return {
  {
    'williamboman/mason.nvim',
    cmd = { 'Mason', 'MasonLog', 'MasonUpdate', 'MasonInstall', 'MasonUninstall', 'MasonUninstallAll' },
    build = ':MasonUpdate', -- :MasonUpdate updates registry contents
    config = true
  },
  {
    'RubixDev/mason-update-all', -- Easily update all Mason packages with one command
    cmd = { 'MasonUpdateAll' },
    config = true
  }
}

-- mason.nvim (https://github.com/williamboman/mason.nvim)
--   Portable package manager for Neovim that runs everywhere Neovim runs. Easily install and manage LSP servers,
--   DAP servers, linters, and formatters.

return {
  {
    'williamboman/mason.nvim',
    cmd = { 'Mason', 'MasonLog', 'MasonUpdate', 'MasonInstall', 'MasonUninstall', 'MasonUninstallAll' },
    build = ':MasonUpdate', -- :MasonUpdate updates registry contents
    opts = {
      ui = {
        border = 'rounded',
        icons = {
          -- The list icon to use for installed packages.
          package_installed = '●',
          -- The list icon to use for packages that are installing, or queued for installation.
          package_pending = '◍',
          -- The list icon to use for packages that are not installed.
          package_uninstalled = '○',
        },
      },
    },
  },
}

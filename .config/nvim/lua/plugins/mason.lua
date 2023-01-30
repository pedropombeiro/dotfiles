-- mason.nvim (https://github.com/williamboman/mason.nvim)
--   Portable package manager for Neovim that runs everywhere Neovim runs. Easily install and manage LSP servers,
--   DAP servers, linters, and formatters.

return {
  "williamboman/mason.nvim",
  cmd = { "Mason", "MasonLog", "MasonInstall", "MasonUninstall", "MasonUninstallAll" },
  config = function()
    require("telescope") -- initialize telescope in order to use its select UI

    require("mason").setup()
  end
}

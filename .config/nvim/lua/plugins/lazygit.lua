-- lazygit.nvim (https://github.com/kdheepak/lazygit.nvim)
-- Plugin for calling lazygit from within neovim.

if vim.fn.has("mac") == 1 then -- Ensure that LazyGit uses same config dir on macOS as in Linux
  vim.api.nvim_create_autocmd({ "BufEnter", "BufAdd", "BufNew", "BufNewFile", "BufWinEnter" }, {
    group = vim.api.nvim_create_augroup("LAZYGIT_CUSTOM_CONFIG", {}),
    callback = function()
      vim.g.lazygit_use_custom_config_file_path = 1
      vim.g.lazygit_config_file_path = vim.fn.expand("~/.config/lazygit/config.yml")
    end
  })
end

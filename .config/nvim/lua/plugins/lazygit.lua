-- LazyGit (https://github.com/kdheepak/lazygit.nvim)
--  Plugin for calling lazygit from within neovim.

-- setup mapping to call :LazyGit
local opts = { noremap = true, silent = true }
local function openLazyGit()
  if vim.env.GIT_DIR == vim.fn.expand("~/.local/share/yadm/repo.git") then
    -- Ensure that we're located at the repository root, so that LazyGit correctly displays diffs
    vim.cmd("cd ~")
  end
  vim.cmd("LazyGit")
end

vim.keymap.set("n", "<leader>gg", openLazyGit, opts)

-- If vim is started from the home directory, assume that GIT_DIR points to yadm repo
--  (makes it possible to use LazyGit directly)

if vim.env.GIT_DIR == nil and vim.fn.getcwd() == vim.fn.expand("~") then
  vim.env.GIT_DIR = vim.fn.expand("~/.local/share/yadm/repo.git")
end

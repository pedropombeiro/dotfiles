-- If vim is started from the home or config directories, assume that GIT_DIR points to yadm repo
--  (makes it possible to use LazyGit directly)

if vim.env.GIT_DIR == nil then
  local cwd       = vim.fn.getcwd()
  local homedir   = vim.fn.expand('~')
  local configdir = vim.fn.expand('~/.config')

  if cwd == homedir or string.sub(cwd, 1, #configdir) == configdir then
    vim.env.GIT_DIR = vim.fn.expand('~/.local/share/yadm/repo.git')
    vim.cmd('cd ~')
  end
end

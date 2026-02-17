local M = {}

M.original_git_dir = nil
M.original_work_tree = nil

local function yadm_repo()
  local repo = vim.fn.systemlist({ "yadm", "introspect", "repo" })[1]
  if repo and repo ~= "" then
    return repo
  end

  return vim.fn.expand("$HOME/.local/share/yadm/repo.git")
end

local function yadm_work_tree()
  return vim.fn.expand("~")
end

function M.switch_git_dir()
  local repo = yadm_repo()
  if not repo or repo == "" then
    vim.notify("YADM repo not found", vim.log.levels.WARN)
    return
  end

  if vim.env.GIT_DIR == repo then
    vim.env.GIT_DIR = M.original_git_dir
    vim.env.GIT_WORK_TREE = M.original_work_tree
    M.original_git_dir = nil
    M.original_work_tree = nil
    vim.notify("Git dir: project", vim.log.levels.INFO)
    return
  end

  M.original_git_dir = vim.env.GIT_DIR
  M.original_work_tree = vim.env.GIT_WORK_TREE
  vim.env.GIT_DIR = repo
  vim.env.GIT_WORK_TREE = yadm_work_tree()
  vim.notify("Git dir: yadm", vim.log.levels.INFO)
end

function M.in_yadm_env(fn)
  local repo = yadm_repo()
  if not repo or repo == "" then
    vim.notify("YADM repo not found", vim.log.levels.WARN)
    return
  end

  local old_git_dir = vim.env.GIT_DIR
  local old_work_tree = vim.env.GIT_WORK_TREE
  vim.env.GIT_DIR = repo
  vim.env.GIT_WORK_TREE = yadm_work_tree()

  local ok, result = pcall(fn, yadm_work_tree())
  vim.env.GIT_DIR = old_git_dir
  vim.env.GIT_WORK_TREE = old_work_tree

  if not ok then
    error(result)
  end

  return result
end

return M

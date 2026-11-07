-- Respect explicit project formatter choices; use Ruff otherwise.
local M = {}

function M.select(bufnr)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local directory = vim.fs.dirname(filename)
  while directory do
    local pyproject = directory .. "/pyproject.toml"
    local lines = vim.fn.filereadable(pyproject) == 1 and vim.fn.readfile(pyproject) or {}
    local content = table.concat(lines, "\n")
    if
      vim.fn.filereadable(directory .. "/ruff.toml") == 1
      or vim.fn.filereadable(directory .. "/.ruff.toml") == 1
      or content:match("%[tool%.ruff[%].]")
    then
      return { "ruff_organize_imports", "ruff_format" }
    end
    if content:match("%[tool%.black%]") then
      local use_isort = content:match("%[tool%.isort%]") or vim.fn.filereadable(directory .. "/.isort.cfg") == 1
      return use_isort and { "isort", "black" } or { "black" }
    end
    if vim.fn.isdirectory(directory .. "/.git") == 1 or vim.fn.filereadable(directory .. "/.git") == 1 then break end
    local parent = vim.fs.dirname(directory)
    if parent == directory then break end
    directory = parent
  end
  return { "ruff_organize_imports", "ruff_format" }
end

return M

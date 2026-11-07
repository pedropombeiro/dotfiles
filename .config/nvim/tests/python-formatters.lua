-- Run from $HOME: nvim --headless -u NONE -l .config/nvim/tests/python-formatters.lua
local select_formatters = dofile(vim.fn.expand("~/.config/nvim/lua/utils/python-formatters.lua")).select
local root = vim.fn.tempname()
vim.fn.mkdir(root .. "/.git", "p")
vim.fn.mkdir(root .. "/src", "p")
local buffer = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(buffer, root .. "/src/example.py")

local function expect(names)
  assert(vim.deep_equal(select_formatters(buffer), names), vim.inspect(select_formatters(buffer)))
end

expect({ "ruff_organize_imports", "ruff_format" })
vim.fn.writefile({ "[tool.black]", "line-length = 88" }, root .. "/pyproject.toml")
expect({ "black" })
vim.fn.writefile({ "[tool.black]", "[tool.isort]" }, root .. "/pyproject.toml")
expect({ "isort", "black" })
vim.fn.writefile({ "[tool.black]", "[tool.ruff.lint]" }, root .. "/pyproject.toml")
expect({ "ruff_organize_imports", "ruff_format" })
vim.fn.writefile({ "[tool.black]" }, root .. "/pyproject.toml")
vim.fn.writefile({}, root .. "/.isort.cfg")
expect({ "isort", "black" })
vim.fn.writefile({}, root .. "/src/ruff.toml")
expect({ "ruff_organize_imports", "ruff_format" })
vim.fn.delete(root .. "/src/ruff.toml")
-- A nested Git root stops discovery of the parent project's Black configuration.
vim.fn.writefile({ "gitdir: ../.git" }, root .. "/src/.git")
expect({ "ruff_organize_imports", "ruff_format" })

vim.api.nvim_buf_delete(buffer, { force = true })
vim.fn.delete(root, "rf")
print("Python formatter selection tests passed")

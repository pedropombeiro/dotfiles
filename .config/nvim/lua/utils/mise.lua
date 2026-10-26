local M = {}

--- Return whether a path names a config file that mise loads, matching what `mise lsp` serves:
--- `mise.toml`, `.mise.toml`, `mise.<env>.toml`, `mise.local.toml`, `mise/config.toml`, and `conf.d/*.toml`.
---@param path string
---@return boolean
function M.is_config_file(path)
  if path == "" then return false end

  local name = vim.fs.basename(path)
  if name:match("^%.?mise%.toml$") or name:match("^%.?mise%.[%w_-]+%.toml$") then return true end

  return path:match("/%.?mise/config%.toml$") ~= nil
    or path:match("/%.?mise/config%.[%w_-]+%.toml$") ~= nil
    or path:match("/%.?mise/conf%.d/[^/]+%.toml$") ~= nil
end

---@param bufnr integer
---@return boolean
function M.is_config_buffer(bufnr) return M.is_config_file(vim.api.nvim_buf_get_name(bufnr)) end

return M

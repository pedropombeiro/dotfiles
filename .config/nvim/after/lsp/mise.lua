-- mise lsp (https://mise.jdx.dev/ide-integration.html#language-server)
--   Language server for mise config files. It ignores other TOML files.
--   Taplo skips mise config files (see taplo.lua), so this server owns hover, completion, and formatting there.

---@type vim.lsp.Config
return {
  cmd = { "mise", "lsp" },
  filetypes = { "toml" },
  -- The server ignores other TOML files, so don't attach a client that does nothing
  root_dir = function(bufnr, on_dir)
    if not require("utils.mise").is_config_buffer(bufnr) then return end

    on_dir(vim.fs.root(bufnr, { "mise.toml", ".mise.toml" }) or vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)))
  end,
}

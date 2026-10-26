---@type vim.lsp.Config
return {
  -- Leave mise config files to `mise lsp` (see mise.lua) to avoid duplicate hover and completion
  root_dir = function(bufnr, on_dir)
    if require("utils.mise").is_config_buffer(bufnr) then return end

    on_dir(vim.fs.root(bufnr, { ".taplo.toml", "taplo.toml", ".git" }))
  end,
  settings = {
    taplo = {
      schema = {
        associations = {
          [".*/sesh/.*\\.toml$"] = "https://github.com/joshmedeski/sesh/raw/main/sesh.schema.json",
        },
      },
    },
  },
}

local install_dir = "/share/homes/admin/opt/vscode-home-assistant"
if not vim.fn.finddir(install_dir) then return {} end

return {
  cmd = { install_dir .. "/node_modules/.bin/ts-node", install_dir .. "/out/server/server.js", "--stdio" },
  filetypes = { "yaml.homeassistant" },
  root_markers = { ".HA_VERSION", "configuration.yaml" },
}

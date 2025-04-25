local function file_exists(name)
  local f = io.open(name, "r")
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

local config_path = "~/Library/Arduino15/arduino-cli.yaml"
if not file_exists(vim.fn.expand(config_path)) then return {} end

return {
  -- stylua: ignore
  cmd = {
    "arduino-language-server",
    "-cli-config", config_path, -- Generated with `arduino-cli config init`
    "-fqbn", "keyboardio:gd32:keyboardio_model_100",
    "-cli", "arduino-cli",
    "-clangd", "clangd",
  },
}

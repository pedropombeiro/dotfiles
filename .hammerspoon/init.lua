require("hs.ipc")

local modules = { "spaces", "sleepwake", "httpserver", "hotkeys" }

for _, mod in ipairs(modules) do
  local path = hs.configdir .. "/" .. mod
  if hs.fs.attributes(path .. ".lua") or hs.fs.attributes(path .. "/init.lua") then require(mod) end
end

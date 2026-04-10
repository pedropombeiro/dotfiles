require("hs.ipc")

local modules = { "spaces", "sleepwake", "httpserver", "hotkeys" }

-- Load modules
for _, mod in ipairs(modules) do
  local path = hs.configdir .. "/" .. mod
  if hs.fs.attributes(path .. ".lua") or hs.fs.attributes(path .. "/init.lua") then require(mod) end
end

-- Watch directory for configuration changes
hs.pathwatcher.new(hs.configdir, hs.reload):start()

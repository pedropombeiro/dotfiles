local configDir = hs.configdir .. "/hotkeys/"
local modules = { "desk", "hyperkey", "opencode", "pastelink", "sesh" }

-- Load modules
for _, mod in ipairs(modules) do
  local path = configDir .. mod .. ".lua"
  if hs.fs.attributes(path) then require("hotkeys." .. mod) end
end

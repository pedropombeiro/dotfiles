local modules = { "spaces", "sleepwake" }

for _, mod in ipairs(modules) do
  local path = hs.configdir .. "/" .. mod .. ".lua"
  if hs.fs.attributes(path) then require(mod) end
end

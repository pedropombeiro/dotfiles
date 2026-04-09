local config = os.getenv("HOME") .. "/.config/hammerspoon/init.lua"

if hs.fs.attributes(config) then dofile(config) end

-- Required for `hs` CLI to communicate with the running Hammerspoon instance
require("hs.ipc")

local log = hs.logger.new("init", "info")

local modules = {
  "busylight",
  "hotkeys",
  "httpserver",
  "meetings",
  "sleepwake",
  "spaces",
  "urlrouter",
  "usb",
  "webcam",
}

-- Load modules. A failing module is reported but does not stop the others,
-- so one broken file cannot take down the whole configuration.
local failed = {}
for _, mod in ipairs(modules) do
  local path = hs.configdir .. "/" .. mod
  if hs.fs.attributes(path .. ".lua") or hs.fs.attributes(path .. "/init.lua") then
    local ok, err = pcall(require, mod)
    if not ok then
      log.e("failed to load " .. mod .. ": " .. tostring(err))
      table.insert(failed, mod)
    end
  end
end
if #failed > 0 then
  hs.notify
    .new({
      title = "Hammerspoon",
      informativeText = "Failed to load: " .. table.concat(failed, ", ") .. ". See the console.",
      withdrawAfter = 0,
    })
    :send()
end

-- Watch the configuration directory and reload once changes settle. yadm
-- deletes and recreates every alternate symlink on most commands, so an
-- immediate reload can run while a module's symlink is briefly missing.
local reloadDelay = 2
local reloadTimer = hs.timer.delayed.new(reloadDelay, hs.reload)
configWatcher = hs.pathwatcher.new(hs.configdir, function() reloadTimer:start() end):start()

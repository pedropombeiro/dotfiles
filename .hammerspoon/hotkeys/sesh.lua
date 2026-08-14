-- Alternatives to tmux `prefix + L` for switching to the last session:
--   * fn+Tab           — Cmd+Tab-like flip, Apple keyboards only
--   * Caps Lock+L      — via hyperBind, which also registers Hyper+L
--
-- fn/Globe is consumed by macOS and never reaches the terminal as an escape
-- sequence, so it cannot be bound in tmux.conf. hs.hotkey.bind rejects "fn" as a
-- modifier too, hence a raw eventtap that inspects the flags directly.
local hyperBind = require("hotkeys.hyperkey").hyperBind

local M = {}

local iterm2 = "com.googlecode.iterm2"
local tmux = "/opt/homebrew/bin/tmux"
local tabKeyCode = hs.keycodes.map["tab"]

local log = hs.logger.new("sesh", "info")

M._tasks = {}

local function run(launchPath, arguments)
  local task
  task = hs.task.new(launchPath, function(exitCode, _, stdErr)
    M._tasks[task] = nil
    if exitCode ~= 0 then log.e(launchPath .. " failed (" .. exitCode .. "): " .. tostring(stdErr)) end
  end, arguments)

  if not task then
    log.e("could not start " .. launchPath)
    return
  end

  M._tasks[task] = true
  task:start()
end

-- Switches the client in the frontmost iTerm2 tab to its last session.
--
-- Calls tmux directly rather than synthesizing `prefix + L`: a synthetic keystroke
-- is delivered while the triggering modifier is still physically held, so the tap
-- that fired would catch its own output and recurse.
--
-- `-c <tty>` targets a specific client because each client tracks its own
-- `client_last_session`; without it tmux picks the most recently active client,
-- which is not necessarily the tab in front of you.
local function switchToLastSession()
  local app = hs.application.frontmostApplication()
  if not app or app:bundleID() ~= iterm2 then return end

  local ok, tty = hs.osascript.applescript(
    'tell application "iTerm2" to return tty of current session of current tab of current window'
  )
  if not ok or type(tty) ~= "string" or tty == "" then
    log.e("could not resolve the frontmost iTerm2 tty")
    return
  end

  run(tmux, { "switch-client", "-c", tty, "-l" })
end

M._tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
  if event:getKeyCode() ~= tabKeyCode then return false end
  -- containExactly so cmd+fn+Tab and friends still pass through untouched.
  if not event:getFlags():containExactly({ "fn" }) then return false end

  switchToLastSession()
  return true
end)

M._tap:start()

hyperBind("l", switchToLastSession)

return M

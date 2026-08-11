local M = {}

local log = hs.logger.new("opencode", "info")
local navigator = os.getenv("HOME") .. "/.local/bin/opencode-goto-waiting"
local tmux = "/opt/homebrew/bin/tmux"

M._tasks = {}

-- Runs a command asynchronously, retaining the task so it is not collected.
-- `arguments` defaults to an empty table: hs.task.new rejects a nil third argument.
local function run(launchPath, arguments, callback)
  local task
  task = hs.task.new(launchPath, function(exitCode, stdOut, stdErr)
    M._tasks[task] = nil
    if callback then callback(exitCode, stdOut, stdErr) end
  end, arguments or {})

  if not task then
    log.e("could not start " .. launchPath)
    return false
  end

  M._tasks[task] = true
  task:start()
  return true
end

local function playNoWaitingSound() run("/usr/bin/afplay", { "/System/Library/Sounds/Tink.aiff" }) end

local function focusTTY(tty)
  local script = string.format(
    [[
      tell application "iTerm2"
        repeat with w in windows
          repeat with t in tabs of w
            repeat with s in sessions of t
              if tty of s is %q then
                select w
                select t
                select s
                return "ok"
              end if
            end repeat
          end repeat
        end repeat
      end tell
      return "not found"
    ]],
    tty
  )
  local success, result = hs.osascript.applescript(script)
  if not success then log.e("failed to focus iTerm2 tab: " .. tostring(result)) end
  return success and result == "ok"
end

function M.activateTTY(tty)
  if tty and tty ~= "" then focusTTY(tty) end
  local app = hs.application.find("iTerm2")
  if app then app:activate() end
end

-- Selects a tmux pane and activates the iTerm2 tab whose client displays it.
-- `pane_tty` is the pane's own pty, not a terminal tab, so resolve `client_tty`
-- from the client attached to the pane's session instead.
function M.activatePane(pane)
  if not pane or pane == "" then
    M.activateTTY()
    return
  end

  run(tmux, { "select-window", "-t", pane }, function()
    run(tmux, { "select-pane", "-t", pane }, function()
      run(tmux, { "display-message", "-t", pane, "-p", "#{client_tty}" }, function(exitCode, stdOut)
        local tty = exitCode == 0 and stdOut:gsub("%s+$", "") or ""
        if tty == "" then log.i("no client_tty for pane " .. pane) end
        M.activateTTY(tty)
      end)
    end)
  end)
end

function M.selectWaiting()
  local started = run(navigator, nil, function(exitCode, stdOut, stdErr)
    if exitCode == 0 then
      log.i("selected " .. stdOut:gsub("%s+$", ""))
      M.activateTTY(stdOut:match("^([^|]+)|"))
    elseif exitCode == 3 then
      hs.alert.show("No OpenCode session waiting", 1)
      playNoWaitingSound()
    elseif exitCode == 4 then
      hs.alert.show("tmux is not running", 1)
    else
      log.e("navigator failed (" .. exitCode .. "): " .. stdErr)
      hs.alert.show("Unable to select OpenCode session", 1)
    end
  end)

  if not started then hs.alert.show("Unable to start OpenCode navigator", 1) end
end

return M

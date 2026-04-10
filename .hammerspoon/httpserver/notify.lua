local log = hs.logger.new("httpserver.notify", "info")

-- Event type → macOS system sound name
local sounds = {
  complete = "Glass",
  subagent_complete = "Pop",
  error = "Basso",
  permission = "Ping",
  question = "Purr",
}

local subtitles = {
  complete = "Session Complete",
  subagent_complete = "Subagent Complete",
  error = "Error",
  permission = "Permission Required",
  question = "Question",
}

local function onActivation(notification, pane)
  hs.application.launchOrFocus("iTerm2")
  if pane and pane ~= "" then
    -- Focus the originating tmux pane so the user lands in the right session
    hs.execute("/opt/homebrew/bin/tmux select-pane -t " .. pane, true)
  end
end

local function notify(params)
  local event = params.event or ""
  local pane = params.pane

  local n = hs.notify.new(function(notification)
    onActivation(notification, pane)
  end, {
    title = params.title or "OpenCode",
    subTitle = subtitles[event] or "",
    informativeText = params.message or "",
    soundName = sounds[event],
    withdrawAfter = 15,
  })

  log.i("notify: " .. event .. " - " .. (params.message or ""))
  n:send()
end

return {
  notify = notify,
}

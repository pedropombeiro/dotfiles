local log = hs.logger.new("httpserver.notify", "info")

-- Event type → macOS system sound name (played via afplay, see below)
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
    withdrawAfter = 15,
  })

  if params.icon and params.icon ~= "" then
    local image = hs.image.imageFromPath(params.icon)
    if image then
      n:contentImage(image)
    end
  end

  log.i("notify: " .. event .. " - " .. (params.message or ""))
  n:send()

  local soundName = sounds[event]
  if soundName then
    -- hs.sound and hs.notify's soundName are unreliable on macOS 26 with eqMac;
    -- use hs.task to run afplay asynchronously without blocking the main thread
    hs.task.new("/usr/bin/afplay", nil, { "/System/Library/Sounds/" .. soundName .. ".aiff" }):start()
  end
end

return {
  notify = notify,
}

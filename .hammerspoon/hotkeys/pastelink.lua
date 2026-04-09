hs.hotkey.bind({ "cmd", "shift" }, "v", function()
  local url = hs.pasteboard.getContents()
  if not url or not url:match("^https?://") then return end

  local title = hs.execute(
    '/usr/bin/curl -sL --max-time 5 "' .. url .. "\" | sed -n 's/.*<title[^>]*>\\([^<]*\\)<\\/title>.*/\\1/p' | head -1"
  )
  if not title or #title == 0 then title = url end
  title = title
    :gsub("%s+$", "")
    :gsub("&amp;", "&")
    :gsub("&lt;", "<")
    :gsub("&gt;", ">")
    :gsub("&quot;", '"')
    :gsub("&#(%d+);", function(n) return string.char(tonumber(n)) end) ---@diagnostic disable-line: param-type-mismatch
    :gsub("&#x(%x+);", function(n) return string.char(tonumber(n, 16)) end)

  local firstPart = title:match("^(.-)%s*·") or title
  firstPart = firstPart:gsub("^%s+", ""):gsub("%s+$", "")

  local html = string.format("<a href='%s'>%s</a>", url, firstPart)

  local original = hs.pasteboard.readAllData()
  hs.pasteboard.clearContents()
  hs.pasteboard.writeDataForUTI("public.html", html)
  hs.pasteboard.writeDataForUTI("public.utf8-plain-text", firstPart, true)

  hs.eventtap.keyStroke({ "cmd" }, "v")
  hs.timer.doAfter(0.5, function() hs.pasteboard.writeAllData(original) end)
end)

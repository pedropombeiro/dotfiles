local log = hs.logger.new("httpserver", "info")
local listenPort = 18990
local configDir = hs.configdir .. "/httpserver/"

-- Sub-modules each return a table of { actionName = handlerFn }.
-- Modules gated by yadm alternates (e.g. ##class.Work) will be absent on
-- non-matching machines and silently skipped via the fs.attributes check.
local modules = { "triggers", "notify" }

-- Parse query string params using hs.http.urlParts, which returns already-
-- unescaped values via NSURLComponents. The callback's `path` arg looks like
-- "/trigger?action=lock&foo=bar", so we prepend a dummy origin to form a URL.
local function parseParams(path)
  local parts = hs.http.urlParts("http://localhost" .. path)
  local params = {}
  if parts.queryItems then
    -- queryItems is an array of single-key tables to preserve order
    for _, item in ipairs(parts.queryItems) do
      for k, v in pairs(item) do
        params[k] = v
      end
    end
  end
  return params
end

-- Merge actions from each sub-module into a single dispatch table
local actions = {}
for _, mod in ipairs(modules) do
  local path = configDir .. mod .. ".lua"
  if hs.fs.attributes(path) then
    local ok, result = pcall(require, "httpserver." .. mod)
    if ok and type(result) == "table" then
      for name, fn in pairs(result) do
        actions[name] = fn
      end
    elseif not ok then
      log.e("failed to load " .. mod .. ": " .. tostring(result))
    end
  end
end

-- Stop any server left over from a previous config reload to free the port
if _G._httpserver then _G._httpserver:stop() end

local server = hs.httpserver.new(false, false)
server:setPort(listenPort)
server:setInterface("localhost")
server:setCallback(function(method, path, headers, body)
  log.i(method .. " " .. path)

  local params = parseParams(path)
  local handler = actions[params.action]

  if handler then
    handler(params)
    return "OK", 200, {}
  else
    return "Unknown action", 400, {}
  end
end)
server:start()
_G._httpserver = server
log.i("listening on port " .. listenPort)

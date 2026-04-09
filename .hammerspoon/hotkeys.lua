local hyper = { "cmd", "alt", "ctrl", "shift" }
local haWebhookBase = "http://ha.home.pombei.ro:8123/api/webhook"

hs.hotkey.bind(hyper, "down", function()
  hs.execute("/usr/bin/curl -sX PUT " .. haWebhookBase .. "/lower_office_desk")
end)

hs.hotkey.bind(hyper, "up", function()
  hs.execute("/usr/bin/curl -sX PUT " .. haWebhookBase .. "/raise_office_desk")
end)

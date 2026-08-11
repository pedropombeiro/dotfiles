-- Hyper+A, not Hyper+O: Shottr's OCR capture owns Ctrl+Opt+Cmd+O.
require("hotkeys.hyperkey").hyperBind("a", function() require("opencode").selectWaiting() end)

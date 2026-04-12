local M = {}

M.uhubctl = "/opt/homebrew/bin/uhubctl"
M.blueutil = "/opt/homebrew/bin/blueutil"

-- CalDigit TS4 hub at uhubctl location; verify with: uhubctl --location 2-1.1.2
M.usbHub = "2-1.1.2"
M.streamDeckPort = "2"
M.elgatoWavePort = "1"

M.airpodsPattern = "AirPods"
M.airpodsAddress = "ec-73-79-44-76-9d"

return M

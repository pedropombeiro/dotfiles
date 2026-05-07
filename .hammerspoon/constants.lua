local M = {}

M.uhubctl = "/opt/homebrew/bin/uhubctl"
M.blueutil = "/opt/homebrew/bin/blueutil"

-- CalDigit TS4 USB2 hub at uhubctl location; verify with: uhubctl --location 2-1.1.2
M.usbHub = "2-1.1.2"
M.streamDeckPort = "2"
M.elgatoWavePort = "1"

-- CalDigit TS4 USB3 hub; verify with: uhubctl --location 2-2.4.1
M.usbHub3 = "2-2.4.1"
M.webcamPort = "2"

M.airpodsPattern = "AirPods"
M.airpodsAddress = "ec-73-79-44-76-9d"
M.dockedAudioDevice = "CalDigit TS4 Audio - Rear"

return M

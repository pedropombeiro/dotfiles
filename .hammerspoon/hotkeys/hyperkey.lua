-- 1. Apply the remap (Caps Lock to F18)
hs.execute(
  'hidutil property --set \'{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x70000006D}]}\''
)

-- 2. State tracking
local f18Down = false
local wasOtherKeyPressed = false

-- 3. Watch F18 (Caps Lock)
-- This replaces the "Modal" with a simple logic gate
local f18Watcher = hs.hotkey.bind({}, "f18", function()
  f18Down = true
  wasOtherKeyPressed = false
end, function()
  f18Down = false
  -- If we released F18 without hitting another key, send Escape
  if not wasOtherKeyPressed then hs.eventtap.keyStroke({}, "escape", 0) end
end)

-- 4. Create a helper function for your shortcuts
-- Uses an eventtap so the key passes through normally when F18 is not held
local hyperBindings = {}

local function hyperBind(key, fn)
  local keyCode = hs.keycodes.map[key]
  local tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
    if event:getKeyCode() == keyCode and f18Down then
      wasOtherKeyPressed = true
      fn()
      return true
    end
  end)
  tap:start()
  table.insert(hyperBindings, tap)

  -- Also make this available with the global hyperkey combo
  local hyper = { "ctrl", "alt", "cmd", "shift" }
  hs.hotkey.bind(hyper, key, fn)
end

-- 5. DEFINE SHORTCUTS HERE
hyperBind("v", function() hs.eventtap.keyStrokes(hs.pasteboard.getContents()) end)

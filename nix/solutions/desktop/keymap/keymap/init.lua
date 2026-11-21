require("hs.ipc")
local config = hs.json.read(hs.configdir .. "/keymap.json")
local engine = dofile(hs.configdir .. "/remap.lua").new(config)

local types, props = hs.eventtap.event.types, hs.eventtap.event.properties
local LEFT_CMD, RIGHT_CMD = 0x08, 0x10

local front = hs.application.frontmostApplication()
front = front and front:bundleID()
Watcher = hs.application.watcher.new(function(_, kind, app)
  if kind == hs.application.watcher.activated then front = app:bundleID() end
end):start()

local function run(argv)
  local args = { "PATH=" .. config.path }
  for _, arg in ipairs(argv) do args[#args + 1] = arg end
  hs.task.new("/usr/bin/env", nil, args):start()
end


Tap = hs.eventtap.new({ types.keyDown, types.keyUp, types.systemDefined }, function(event)
  local raw
  if event:getType() == types.systemDefined then
    local system = event:systemKey()
    raw = { type = "systemDefined", systemKey = system.key, down = system.down, repeated = system["repeat"] or false }
  else
    local code = event:getKeyCode()
    raw = {
      type = event:getType() == types.keyDown and "keyDown" or "keyUp",
      keyCode = code,
      name = hs.keycodes.map[code],
      repeated = event:getProperty(props.keyboardEventAutorepeat) ~= 0,
    }
  end
  local read = engine:read(raw)
  if not read then return false end
  local flags, rawFlags = event:getFlags(), event:rawFlags()
  read.leftCmd = rawFlags & LEFT_CMD ~= 0
  read.rightCmd = rawFlags & RIGHT_CMD ~= 0
  read.ctrl = flags.ctrl or false
  read.alt = flags.alt or false
  read.shift = flags.shift or false
  read.app = front
  local what, arg = engine:decide(read)
  if what == "pass" then return false end
  if what == "rewrite" then event:setFlags(arg) return false end
  if what == "run" then run(arg) end
  return true
end)

local stateDir = os.getenv("HOME") .. "/.local/state/keymap"
hs.fs.mkdir(os.getenv("HOME") .. "/.local/state")
hs.fs.mkdir(stateDir)
local function arm()
  local granted = hs.accessibilityState(false)
  local file = io.open(stateDir .. "/remapper.json", "w")
  if file then
    file:write(string.format('{"accessibility":%s,"pid":%d}\n', tostring(granted), hs.processInfo.processID))
    file:close()
  end
  if granted and not Tap:isEnabled() then Tap:start() end
end

if not hs.accessibilityState(false) then hs.accessibilityState(true) end
arm()
Timer = hs.timer.doEvery(2, arm)

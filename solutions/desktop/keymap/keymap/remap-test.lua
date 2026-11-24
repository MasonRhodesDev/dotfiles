local dir = arg[1]
local config = dofile(dir .. "/config.lua")
local cases = dofile(dir .. "/cases.lua")
local remap = dofile(dir .. "/remap.lua")

local failed = 0
local function same(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return a == b end
  for k, v in pairs(a) do if not same(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end
local function show(v)
  if type(v) ~= "table" then return tostring(v) end
  local parts = {}
  for k, x in pairs(v) do parts[#parts + 1] = tostring(k) .. "=" .. show(x) end
  table.sort(parts)
  return "{" .. table.concat(parts, " ") .. "}"
end
local function expect(name, engine, event, what, arg)
  local gotWhat, gotArg = engine:decide(event)
  if gotWhat ~= what or not same(gotArg, arg) then
    failed = failed + 1
    print(string.format("FAIL %s: got %s %s, want %s %s", name, gotWhat, show(gotArg), what, show(arg)))
  end
end
local function press(fields)
  local event = { down = true, repeated = false, leftCmd = false, rightCmd = false, ctrl = false, alt = false, shift = false, app = "com.apple.Safari" }
  for k, v in pairs(fields) do event[k] = v end
  return event
end

assert(#cases.super > 0 and #cases.super == #config.super, "one Super rule per Super bind")
for _, case in ipairs(cases.super) do
  local chord = { key = case.key, ctrl = case.ctrl, alt = case.alt, shift = case.shift }
  local function with(fields)
    local event = press(chord)
    for k, v in pairs(fields) do event[k] = v end
    return event
  end
  local engine = remap.new(config)
  expect(case.name .. ": left Cmd chord", engine, with({ leftCmd = true }), "run", case.arg)
  expect(case.name .. ": its repeat does nothing", engine, with({ leftCmd = true, repeated = true }), "swallow")
  expect(case.name .. ": its key-up is swallowed, Cmd already released", engine, with({ down = false }), "swallow")
  expect(case.name .. ": the next key-up passes", engine, with({ down = false }), "pass")

  engine = remap.new(config)
  expect(case.name .. ": in a terminal too", engine, with({ leftCmd = true, app = "net.kovidgoyal.kitty" }), "run", case.arg)
  engine = remap.new(config)
  expect(case.name .. ": right Cmd is a plain Cmd", engine, with({ rightCmd = true }), "pass")
  engine = remap.new(config)
  expect(case.name .. ": both Cmd keys are not Super", engine, with({ leftCmd = true, rightCmd = true }), "pass")
  engine = remap.new(config)
  expect(case.name .. ": key held, then Cmd: the repeat does nothing", engine, with({ leftCmd = true, repeated = true }), "swallow")
  expect(case.name .. ": and the app still gets its key-up", engine, with({ down = false }), "pass")
  engine = remap.new(config)
  expect(case.name .. ": press", engine, with({ leftCmd = true }), "run", case.arg)
  expect(case.name .. ": pressed again after a lost key-up, it acts again", engine, with({ leftCmd = true }), "run", case.arg)
  expect(case.name .. ": a lost key-up does not eat the next plain press", (function() local e = remap.new(config); e:decide(with({ leftCmd = true })); return e end)(), with({}), "pass")
end

local engine = remap.new(config)
expect("Ctrl+C in an app is Cmd+C", engine, press({ key = "c", ctrl = true }), "rewrite", { cmd = true })
expect("its repeat too", engine, press({ key = "c", ctrl = true, repeated = true }), "rewrite", { cmd = true })
expect("its key-up too, Ctrl already released", engine, press({ key = "c", down = false }), "rewrite", { cmd = true })
expect("then C is a plain C", engine, press({ key = "c" }), "pass")
expect("Ctrl+Shift+T is Cmd+Shift+T", engine, press({ key = "t", ctrl = true, shift = true }), "rewrite", { cmd = true, shift = true })
for _, id in ipairs(config.terminals) do
  expect("Ctrl+C stays Ctrl+C in " .. id, remap.new(config), press({ key = "c", ctrl = true, app = id }), "pass")
end
engine = remap.new(config)
engine:decide(press({ key = "c", ctrl = true }))
expect("after a lost key-up, a plain C in a terminal is a plain C", engine, press({ key = "c", app = "net.kovidgoyal.kitty" }), "pass")
engine = remap.new(config)
expect("C held, then Ctrl: the repeat stays a C", engine, press({ key = "c", ctrl = true, repeated = true }), "pass")
expect("and its key-up passes", engine, press({ key = "c", down = false }), "pass")
expect("Ctrl+C with no app known is rewritten", remap.new(config), press({ key = "c", ctrl = true, app = false }), "rewrite", { cmd = true })
expect("Ctrl+Opt+C is left alone", remap.new(config), press({ key = "c", ctrl = true, alt = true }), "pass")
expect("Ctrl+Cmd+Q is left alone (right Cmd)", remap.new(config), press({ key = "q", ctrl = true, rightCmd = true }), "pass")
expect("Ctrl+1 is left alone", remap.new(config), press({ key = "1", ctrl = true }), "pass")
expect("Ctrl+Tab is left alone", remap.new(config), press({ key = "tab", ctrl = true }), "pass")
expect("left Cmd+W has no bind and stays Cmd+W", remap.new(config), press({ key = "w", leftCmd = true }), "pass")
expect("left Cmd+Tab stays the app switcher", remap.new(config), press({ key = "tab", leftCmd = true }), "pass")
expect("a plain key passes", remap.new(config), press({ key = "a" }), "pass")

local arrives = {
  F1 = { type = "systemDefined", systemKey = "BRIGHTNESS_DOWN" },
  F2 = { type = "systemDefined", systemKey = "BRIGHTNESS_UP" },
  F3 = { type = "keyDown", keyCode = 160 },
  F4 = { type = "keyDown", keyCode = 177 },
  F5 = { type = "keyDown", keyCode = 176 },
  F6 = { type = "keyDown", keyCode = 178 },
}

local function apple(key, mods, over)
  over = over or {}
  local down = over.down ~= false
  local arrive = arrives[key] or { type = "keyDown", name = key:lower() }
  local raw = { type = arrive.type, keyCode = arrive.keyCode, systemKey = arrive.systemKey, name = arrive.name, down = down, repeated = over.repeated or false }
  if raw.type == "keyDown" and not down then raw.type = "keyUp" end
  local event = remap.new(config):read(raw)
  assert(event, key .. ": the remapper reads the key")
  event.leftCmd = mods.cmd or false
  if over.leftCmd ~= nil then event.leftCmd = over.leftCmd end
  event.rightCmd = over.rightCmd or false
  event.shift = mods.shift or false
  if over.shift ~= nil then event.shift = over.shift end
  event.ctrl = mods.ctrl or false
  if over.ctrl ~= nil then event.ctrl = over.ctrl end
  event.alt = mods.alt or false
  event.app = over.app or "com.apple.Safari"
  return event
end

local function bound(key, cmd, shift)
  for _, other in ipairs(cases.fn) do
    if other.key == key and other.cmd == cmd and other.shift == shift then return other.arg end
  end
end

assert(#cases.fn > 0 and #cases.fn == #config.fn, "one Apple key rule per Apple key bind")
for _, case in ipairs(cases.fn) do
  local function on(over) return apple(case.key, case, over) end
  local engine = remap.new(config)
  expect(case.name .. ": pressed", engine, on(), "run", case.arg)
  expect(case.name .. ": its repeat does nothing", engine, on({ repeated = true }), "swallow")
  expect(case.name .. ": its key-up is swallowed", engine, on({ down = false }), "swallow")
  expect(case.name .. ": the next key-up passes", engine, on({ down = false }), "pass")
  expect(case.name .. ": pressed again, it acts again", engine, on(), "run", case.arg)
  engine = remap.new(config)
  expect(case.name .. ": key held, then the modifiers: the repeat does nothing", engine, on({ repeated = true }), "swallow")
  expect(case.name .. ": in a terminal too", remap.new(config), on({ app = "net.kovidgoyal.kitty" }), "run", case.arg)
  if case.cmd then
    expect(case.name .. ": with right Cmd too", remap.new(config), on({ leftCmd = false, rightCmd = true }), "run", case.arg)
    expect(case.name .. ": without Cmd it stays the Mac's key", remap.new(config), on({ leftCmd = false }), "pass")
  else
    expect(case.name .. ": with Cmd it stays the Mac's key", remap.new(config), on({ leftCmd = true }), "pass")
  end
  expect(case.name .. ": with Ctrl toggled it stays the Mac's key", remap.new(config), on({ ctrl = not case.ctrl }), "pass")
  local other = bound(case.key, case.cmd, not case.shift)
  if other then
    expect(case.name .. ": with Shift toggled it is the other bind", remap.new(config), on({ shift = not case.shift }), "run", other)
  else
    expect(case.name .. ": with Shift toggled it stays the Mac's key", remap.new(config), on({ shift = not case.shift }), "pass")
  end
end

for _, key in ipairs({ "F1", "F2", "F5", "F6" }) do
  local engine = remap.new(config)
  expect(key .. " alone stays the Mac's key", engine, apple(key, {}), "pass")
  expect(key .. ": its repeat too", engine, apple(key, {}, { repeated = true }), "pass")
  expect(key .. ": its key-up too", engine, apple(key, {}, { down = false }), "pass")
end

engine = remap.new(config)
assert(engine:read({ type = "keyDown", keyCode = 4095, repeated = false }) == nil, "a key the remapper cannot name is not read")
assert(engine:read({ type = "systemDefined", systemKey = "PLAY", down = true, repeated = false }) == nil, "a media key the remapper does not bind is not read")
assert(engine:read({ type = "keyDown", keyCode = 8, name = "c", repeated = false }).key == "c", "an ordinary key keeps its name")

assert(#cases.userKeyMapping == 1, "one key mapping")
local caps = cases.userKeyMapping[1]
if caps.HIDKeyboardModifierMappingSrc ~= 0x700000039 or caps.HIDKeyboardModifierMappingDst ~= 0x7000000E1 then
  failed = failed + 1
  print(string.format("FAIL Caps Lock (0x700000039) maps to left Shift (0x7000000E1): got %#x to %#x", caps.HIDKeyboardModifierMappingSrc, caps.HIDKeyboardModifierMappingDst))
end

if failed > 0 then os.exit(1) end
print(string.format("remap: %d Super binds, %d Apple key binds, the Apple keys left to macOS, Caps Lock as Shift and the Ctrl rules behave", #cases.super, #cases.fn))

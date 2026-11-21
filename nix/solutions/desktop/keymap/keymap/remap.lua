local M = {}

local function chord(key, ctrl, alt, shift, cmd)
  return key .. "|" .. (ctrl and "c" or "") .. (alt and "a" or "") .. (shift and "s" or "") .. (cmd and "m" or "")
end

function M.new(config)
  local super, fn, terminals, letters = {}, {}, {}, {}
  for _, rule in ipairs(config.super) do
    local has = {}
    for _, mod in ipairs(rule.mods) do has[mod] = true end
    local at = chord(rule.key, has.ctrl, has.alt, has.shift)
    assert(not super[at], "two Super rules for " .. at)
    super[at] = rule
  end
  for _, rule in ipairs(config.fn) do
    local has = {}
    for _, mod in ipairs(rule.mods) do has[mod] = true end
    local at = chord(rule.key, has.ctrl, has.alt, has.shift, has.cmd)
    assert(not fn[at], "two Apple key rules for " .. at)
    fn[at] = rule
  end
  for _, id in ipairs(config.terminals) do terminals[id] = true end
  for letter in config.ctrlToCmd:gmatch(".") do letters[letter] = true end
  local keyCodes, systemKeys = config.appleKeys.keyCodes, config.appleKeys.systemKeys

  local held = {}

  local engine = {}
  function engine.read(_, raw)
    if raw.type == "systemDefined" then
      local key = systemKeys[raw.systemKey or ""]
      if not key then return nil end
      return { key = key, down = raw.down, repeated = raw.repeated }
    end
    local key = keyCodes[tostring(raw.keyCode)] or raw.name
    if not key then return nil end
    return { key = key, down = raw.type == "keyDown", repeated = raw.repeated }
  end

  function engine.decide(_, event)
    local was = held[event.key]
    if not event.down then
      held[event.key] = nil
      if was == nil then return "pass" end
      if was == true then return "swallow" end
      return "rewrite", was
    end
    if was ~= nil and not event.repeated then held[event.key], was = nil, nil end
    if was == true then return "swallow" end
    if was then return "rewrite", was end

    local apple = fn[chord(event.key, event.ctrl, event.alt, event.shift, event.leftCmd or event.rightCmd)]
    if apple then
      if event.repeated then return "swallow" end
      held[event.key] = true
      return "run", apple.run
    end

    if event.leftCmd and not event.rightCmd then
      local rule = super[chord(event.key, event.ctrl, event.alt, event.shift)]
      if rule then
        if event.repeated then return "swallow" end
        held[event.key] = true
        return "run", rule.run
      end
      return "pass"
    end

    if event.ctrl and not event.alt and not event.leftCmd and not event.rightCmd
        and not event.repeated and letters[event.key] and not terminals[event.app or ""] then
      local flags = { cmd = true, shift = event.shift or nil }
      held[event.key] = flags
      return "rewrite", flags
    end
    return "pass"
  end
  return engine
end

return M

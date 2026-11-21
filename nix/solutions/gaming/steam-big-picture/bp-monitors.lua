local C = BP_COMMON or dofile((os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/bp-common.lua")

local function read_keep()
    local env = os.getenv("BP_KEEP_MONITOR_DESC")
    if env and env ~= "" then return env end
    local f = io.open(C.CONFIG_BASE .. "/hypr-de/xwayland-primary", "r")
    if not f then return nil end
    local line = f:read("*l") or ""
    f:close()
    line = line:gsub("%s+", "")
    if line == "" then return nil end
    return line
end
local KEEP_DESC = read_keep()

local COALESCE_MS    = 50

local BP_EXIT_MAX_MS = 15000
local PENDING_MAX_MS = 6000
local RELEASE_MAX_MS = 6000
local HOLD_MAX_MS    = 90000
local SAFETY_MS      = 30000

local S_NORMAL, S_BP, S_STREAM = "NORMAL", "BP", "STREAM"

local state     = S_NORMAL
local pending   = nil
local kept      = nil
local snapshot  = {}
local disabled  = {}
local homes     = {}
local closing   = nil
local held      = false
local held_logged = false
local releasing = nil
local desk      = nil
local eval_gen  = 0

local sh_quote = C.sh_quote
local log = C.logger("hypr-bp-monitors")
if not KEEP_DESC then log("no keep monitor configured (hypr-de/xwayland-primary); Big Picture leaves monitors alone") end

local function has_prefix(s, p)
    return type(s) == "string" and p ~= "" and s:sub(1, #p) == p
end

local function mon_key(m)
    if type(m.description) == "string" and m.description ~= "" then return m.description end
    return m.name
end

local function is_keep(m)
    if not KEEP_DESC then return false end
    return m.name == KEEP_DESC
        or (type(m.description) == "string" and m.description:find(KEEP_DESC, 1, true) ~= nil)
end

local function streaming()
    if not (BP_FOCUS and BP_FOCUS.streaming) then return false end
    local ok, live = pcall(BP_FOCUS.streaming)
    return ok and live == true
end

local function later(ms, fn) C.later(ms, fn, log) end

local function timer()
    local gen = 0
    return {
        arm = function(ms, fn)
            gen = gen + 1
            local mine = gen
            later(ms, function() if mine == gen then fn() end end)
        end,
        cancel = function() gen = gen + 1 end,
    }
end
local t_state   = timer()
local t_release = timer()
local t_safety  = timer()

local function read_profile()
    local rules, order, ws = {}, {}, {}
    local f = io.open(C.CONFIG_BASE .. "/hypr/profiles/.active.lua", "r")
    if not f then return { rules = rules, order = order, ws = ws } end
    local text = f:read("*a")
    f:close()
    for tbl in text:gmatch('hl%.monitor%(%s*(%b{})%s*%)') do
        local out = tbl:match('output%s*=%s*"([^"]+)"')
        if out then
            rules[out] = tbl
            order[#order + 1] = out
        end
    end
    for tbl in text:gmatch('hl%.workspace_rule%(%s*(%b{})%s*%)') do
        local id = tonumber(tbl:match('workspace%s*=%s*"(%d+)"'))
        local mon = tbl:match('monitor%s*=%s*"([^"]+)"')
        if id and mon then ws[id] = mon end
    end
    return { rules = rules, order = order, ws = ws }
end

local function profile_rule_names()
    return (desk or read_profile()).order
end

local function rule_for(m, names)
    for _, n in ipairs(names) do
        if has_prefix(n, "desc:") then
            if has_prefix(m.description, n:sub(6)) then return n end
        elseif n == m.name then
            return n
        end
    end
    if mon_key(m) == m.name then return m.name end
    return "desc:" .. m.description
end

local bp_window = C.bp_window

local function bp_present()
    return bp_window() ~= nil
end

local function monitor_by_key(key)
    for _, m in ipairs(hl.get_monitors()) do
        if m.enabled and mon_key(m) == key then return m end
    end
    return nil
end

local function take_snapshot()
    snapshot = {}
    desk = read_profile()
    for _, m in ipairs(hl.get_monitors()) do
        if m.enabled then
            snapshot[#snapshot + 1] = { name = m.name, key = mon_key(m),
                                        w = m.width, h = m.height, keep = is_keep(m) }
        end
    end
end

local function all_enabled(keys)
    for _, k in ipairs(keys) do
        if not monitor_by_key(k) then return false end
    end
    return #keys > 0
end

local function snapshot_keys()
    local keys = {}
    for _, c in ipairs(snapshot) do keys[#keys + 1] = c.key end
    return keys
end

local function area_16x9(c)
    local w, h = c.w, c.h
    if not w or not h or w <= 0 or h <= 0 then return 0 end
    local fw = math.min(w, math.floor(h * 16 / 9))
    local fh = math.min(h, math.floor(w * 9 / 16))
    return fw * fh
end

local function choose_bp()
    for _, c in ipairs(snapshot) do
        if c.keep then return c end
    end
    return nil
end

local function choose_stream()
    local best, best_area = nil, -1
    for _, c in ipairs(snapshot) do
        local a = area_16x9(c)
        if a > best_area or (a == best_area and c.keep) then
            best, best_area = c, a
        end
    end
    return best or choose_bp()
end

local function apply_override(keep)
    if not keep then return false end
    local targets = {}
    for _, m in ipairs(hl.get_monitors()) do
        if m.enabled and m.name ~= keep.name then targets[#targets + 1] = m end
    end
    if #targets == 0 then
        log("WARNING only " .. keep.name .. " is enabled and nothing was disabled "
            .. "here, so no revert is possible; is a profile holding the others off?")
        return false
    end

    for _, ws in ipairs(hl.get_workspaces()) do
        if ws.monitor and not ws.special and ws.id and ws.id > 0 and not homes[ws.id] then
            for _, t in ipairs(targets) do
                if t.name == ws.monitor.name then homes[ws.id] = mon_key(t) end
            end
        end
    end

    local names = profile_rule_names()
    for _, m in ipairs(targets) do
        local rule = rule_for(m, names)
        hl.monitor({ output = rule, disabled = true })
        disabled[#disabled + 1] = { rule = rule, key = mon_key(m) }
        log("disabled " .. mon_key(m) .. " via " .. rule)
    end
    kept = keep
    hl.exec_cmd("xrandr --output " .. sh_quote(keep.name) .. " --primary")
    return true
end

local function home_for(id, observed_key)
    local sel = desk and desk.ws[id]
    if sel then
        for _, m in ipairs(hl.get_monitors()) do
            if m.enabled and (m.name == sel or (has_prefix(sel, "desc:") and has_prefix(m.description, sel:sub(6)))) then
                return m
            end
        end
    end
    return monitor_by_key(observed_key)
end

local function finish_release(why)
    local r = releasing
    if not r then return end
    releasing = nil
    t_release.cancel()
    if not kept then
        for id, key in pairs(r.homes) do
            local mon = home_for(id, key)
            local ws  = hl.get_workspace(id)
            if mon and ws and (not ws.monitor or ws.monitor.name ~= mon.name) then
                hl.dispatch(hl.dsp.workspace.move({ workspace = id, monitor = mon.name }))
                log("re-homed workspace " .. id .. " to " .. key)
            end
        end
    end
    hl.exec_cmd("/usr/lib/hypr-de/set-xwayland-primary.sh")
    if why then log(why) end
end

local function release()
    local rules = desk and desk.rules or {}
    local function restore(rule, key)
        local tbl = rules[rule]
        if tbl then
            local chunk = load("return " .. tbl)
            if chunk then
                hl.monitor(chunk())
                log("restored " .. key .. " via " .. rule)
                return
            end
        end
        hl.monitor({ output = rule, disabled = false })
        log("re-enabled " .. key .. " via " .. rule)
    end
    if kept then
        local names = profile_rule_names()
        local m = monitor_by_key(kept.key)
        if m then restore(rule_for(m, names), kept.key) end
    end
    for _, d in ipairs(disabled) do restore(d.rule, d.key) end
    releasing = { homes = homes, keys = snapshot_keys() }
    disabled, homes, kept = {}, {}, nil
    t_release.arm(RELEASE_MAX_MS, function()
        finish_release("WARNING: a released monitor never came back within "
            .. RELEASE_MAX_MS .. "ms; finishing with what is enabled")
    end)
end

local evaluate

local function arm_safety()
    t_safety.arm(SAFETY_MS, function()
        if state == S_NORMAL then return end
        local before = state
        evaluate()
        if state ~= before or pending then
            log("WARNING: safety check left " .. before .. "; an event was missed")
        end
        arm_safety()
    end)
end

local function enter(target)
    local keep = (target == S_STREAM) and choose_stream() or choose_bp()
    if not apply_override(keep) then
        state, pending = S_NORMAL, nil
        return
    end
    state, pending = target, nil
    t_state.cancel()
    log("-> " .. state .. " keeping " .. keep.key)
    arm_safety()
end

local function to_normal(why)
    release()
    state, pending, snapshot, closing = S_NORMAL, nil, {}, nil
    t_state.cancel()
    t_safety.cancel()
    log("-> NORMAL (" .. why .. ")")
end

local function await_bp_exit()
    local w = bp_window()
    if not w then
        to_normal("session over")
        return
    end
    closing = w.address
    log("session over, waiting for Steam to close Big Picture " .. tostring(w.address))
    t_state.arm(BP_EXIT_MAX_MS, function()
        if state == S_STREAM and closing then
            log("WARNING: Big Picture still open " .. BP_EXIT_MAX_MS .. "ms after the session ended; releasing anyway")
            to_normal("session over, Big Picture still open")
        end
    end)
end

local function switch_to(target)
    release()
    pending = target
    log("-> " .. target .. " pending; released, waiting for all monitors")
    t_state.arm(PENDING_MAX_MS, function()
        if pending == target then
            log("WARNING: pending " .. target .. " timed out after " .. PENDING_MAX_MS .. "ms; applying with what is enabled")
            enter(target)
        end
    end)
end

evaluate = function()
    if releasing and all_enabled(releasing.keys) then finish_release() end

    if kept and not monitor_by_key(kept.key) then
        to_normal("kept monitor " .. kept.key .. " is gone")
        return
    end

    if pending then
        if all_enabled(snapshot_keys()) then enter(pending) end
        return
    end

    if state == S_NORMAL then
        if not (bp_present() or streaming()) then return end
        if not bp_present() then log("Remote Play session with no Big Picture window, entering STREAM") end
        take_snapshot()
        enter(streaming() and S_STREAM or S_BP)

    elseif state == S_BP then
        if streaming() then
            switch_to(S_STREAM)
        elseif not bp_present() then
            if held then
                if not held_logged then log("Big Picture gone while Steam restarts; holding BP") end
                held_logged = true
            else
                to_normal("Big Picture gone")
            end
        end

    elseif state == S_STREAM then
        if closing then
            if not bp_present() then to_normal("session over, Big Picture closed") end
        elseif not streaming() then
            await_bp_exit()
        end
    end
end

local function schedule_evaluate()
    eval_gen = eval_gen + 1
    local mine = eval_gen
    later(COALESCE_MS, function()
        if mine == eval_gen then evaluate() end
    end)
end

local function hold(on)
    held, held_logged = (on and true or false), false
    if held then
        log("hold: Steam restarting, BP will not release")
        t_state.arm(HOLD_MAX_MS, function()
            if held then
                log("WARNING: hold never released after " .. HOLD_MAX_MS .. "ms; releasing")
                held = false
                schedule_evaluate()
            end
        end)
    else
        log("hold released")
        t_state.cancel()
        schedule_evaluate()
    end
end

hl.on("window.open",    function() schedule_evaluate() end)
hl.on("window.title",   function() schedule_evaluate() end)
hl.on("window.close",   function() schedule_evaluate() end)
hl.on("window.destroy", function() schedule_evaluate() end)
hl.on("monitor.added",   function() schedule_evaluate() end)
hl.on("monitor.removed", function() schedule_evaluate() end)
hl.on("monitor.layout_changed", function() schedule_evaluate() end)

local function status()
    local snap = {}
    for _, c in ipairs(snapshot) do snap[#snap + 1] = c.name end
    local dis = {}
    for _, d in ipairs(disabled) do dis[#dis + 1] = d.key end
    return ("state=%s pending=%s kept=%s held=%s closing=%s releasing=%s snapshot=[%s] disabled=[%s] bp=%s streaming=%s"):format(
        state, tostring(pending), kept and kept.name or "nil", tostring(held),
        tostring(closing), tostring(releasing ~= nil),
        table.concat(snap, ","), table.concat(dis, ","),
        tostring(bp_present()), tostring(streaming()))
end

BP_MONITORS = { schedule_evaluate = schedule_evaluate, hold = hold, status = status }

local ok, err = pcall(evaluate)
if not ok then log("error at load: " .. tostring(err)) end
schedule_evaluate()

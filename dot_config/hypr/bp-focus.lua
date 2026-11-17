local C = BP_COMMON or dofile((os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/bp-common.lua")
local BP_CLASS = C.BP_CLASS

local STREAM_LOG = os.getenv("HOME") .. "/.local/share/Steam/logs/streaming_log.txt"
local STREAM_LOG_PREV = STREAM_LOG:gsub("%.txt$", ".previous.txt")
local STREAM_WINDOW = 1200000
local STREAM_START  = "Streaming started to "
local STREAM_STOP   = "PipeWire: Deinitializing streaming"

local COALESCE_MS = 50
local USER_SPECIAL = 3

local last_user_special = 0

local log = C.logger("hypr-bp-focus")

local bp_window = C.bp_window

local LAUNCHER_CLASSES = { ["org.prismlauncher.PrismLauncher"] = true }

local steam_launch_cache = {}

local function under_steam_launch(pid)
    local cached = steam_launch_cache[pid]
    if cached ~= nil then return cached end
    local root = pid
    local function remember(v)
        if root then
            local n = 0
            for _ in pairs(steam_launch_cache) do n = n + 1 end
            if n > 256 then steam_launch_cache = {} end
            steam_launch_cache[root] = v
        end
        return v
    end
    for _ = 1, 40 do
        if not pid or pid <= 1 then return remember(false) end
        local f = io.open("/proc/" .. pid .. "/cmdline", "rb")
        if not f then return false end
        local cmdline = f:read("*a") or ""
        f:close()
        if cmdline:find("SteamLaunch", 1, true) then return remember(true) end
        local s = io.open("/proc/" .. pid .. "/stat", "r")
        if not s then return false end
        local stat = s:read("*a") or ""
        s:close()
        local after = stat:match("%)%s*(.*)$")
        if not after then return false end
        local ppid = after:match("^%S+%s+(%d+)")
        pid = tonumber(ppid)
    end
    return remember(false)
end

local function is_game(w)
    local cls, title = w.class or "", w.title or ""
    if LAUNCHER_CLASSES[cls] or cls == BP_CLASS then return false end
    if cls:match("^steam_app_%d+$") or cls == "gamescope" or title == "Godot" then
        return true
    end
    if cls:match("^Minecraft") then return true end
    return under_steam_launch(w.pid)
end

local function last_boundary_in(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local size = f:seek("end")
    f:seek("set", math.max(0, size - STREAM_WINDOW))
    local text = f:read("*a") or ""
    f:close()

    local live, pos = nil, 1
    while true do
        local a = text:find(STREAM_START, pos, true)
        local b = text:find(STREAM_STOP, pos, true)
        if not a and not b then break end
        if a and (not b or a < b) then
            live, pos = true, a + #STREAM_START
        else
            live, pos = false, b + #STREAM_STOP
        end
    end
    return live
end

local function stream_boundary_says_live()
    local live = last_boundary_in(STREAM_LOG)
    if live ~= nil then return live end
    return last_boundary_in(STREAM_LOG_PREV)
end

local function streaming()
    return stream_boundary_says_live() == true
end

local function game_session()
    return bp_window() ~= nil or streaming()
end

local function later(ms, fn) C.later(ms, fn, log) end

local function window_by_address(addr)
    for _, w in ipairs(hl.get_windows()) do
        if w.address == addr then return w end
    end
    return nil
end

local function focus_address(addr)
    hl.dispatch(hl.dsp.focus({ window = "address:" .. addr }))
end

local function fullscreen_on()
    hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen", action = "set" }))
end

local function dismiss_specials(reason)
    local restore = hl.get_active_monitor()
    local n = 0
    for _, m in ipairs(hl.get_monitors()) do
        if m.enabled then
            if restore and m.name ~= restore.name then
                hl.dispatch(hl.dsp.focus({ monitor = m.name }))
            end
            local sp = hl.get_active_special_workspace()
            if sp and sp.name then
                local aw = hl.get_active_window()
                local lw = sp.last_window
                log(("dismissing %s on %s (%s) focus=%s/%s resident=%s"):format(
                    sp.name, m.name, reason,
                    tostring(aw and aw.class), tostring(aw and aw.title),
                    tostring(lw and lw.class)))
                hl.dispatch(hl.dsp.workspace.toggle_special(sp.name:gsub("^special:", "")))
                n = n + 1
            end
        end
    end
    if restore then hl.dispatch(hl.dsp.focus({ monitor = restore.name })) end
    return n
end

local function set_focus_on_activate(w, on)
    hl.dispatch(hl.dsp.window.set_prop({
        window = "address:" .. w.address,
        prop   = "focus_on_activate",
        value  = on and "true" or "false",
    }))
end

local props_applied

local function apply_game_props(force)
    local on = game_session()
    if not force and props_applied == on then return end
    props_applied = on
    for _, w in ipairs(hl.get_windows()) do
        if is_game(w) then set_focus_on_activate(w, on) end
    end
    log("games focus_on_activate=" .. tostring(on))
end

local function prioritise(addr, reason)
    local w = window_by_address(addr)
    if not w then return end
    log("prioritising " .. (w.class or "?") .. " (" .. reason .. ")")
    focus_address(addr)
    dismiss_specials("game priority")
end

local function newest_game()
    local found
    for _, w in ipairs(hl.get_windows()) do
        if is_game(w) and w.mapped then found = w end
    end
    return found
end

local M = {}

local handled = {}

function M.consider(w, reason)
    if not w or not w.address then return end
    if not is_game(w) then return end
    local session = game_session()
    set_focus_on_activate(w, session)
    if not session then
        log("game " .. (w.class or "?") .. " appeared with no session -> background")
        return
    end
    if handled[w.address] then return end
    handled[w.address] = true
    prioritise(w.address, reason)
end

local props_gen = 0
local function props_soon()
    props_gen = props_gen + 1
    local mine = props_gen
    later(COALESCE_MS, function() if mine == props_gen then apply_game_props() end end)
end

function M.on_open(w)
    M.consider(type(w) == "userdata" and w or newest_game(), "opened")
    props_soon()
end

function M.on_title(w)
    if type(w) == "userdata" then M.consider(w, "titled") end
    props_soon()
end

function M.on_close(w)
    if type(w) == "userdata" and w.address then handled[w.address] = nil end
    props_soon()
end

function M.on_active(w)
    if type(w) ~= "userdata" then return end
    if is_game(w) then
        if handled[w.address] and game_session() and (w.fullscreen or 0) ~= 2 then
            fullscreen_on()
        end
        return
    end
    if not C.is_bp(w) then return end
    local g = streaming() and newest_game()
    if g and handled[g.address] then
        prioritise(g.address, "Big Picture raised over a streamed game")
    elseif (w.fullscreen or 0) ~= 2 then
        fullscreen_on()
    end
end

function M.on_special()
    local function stray()
        return game_session() and (os.time() - last_user_special) >= USER_SPECIAL
    end
    if not stray() then return end
    later(50, function() if stray() then dismiss_specials("not user-initiated") end end)
end

function M.on_rules() later(50, apply_game_props) end

function M.guide()
    local g = newest_game()
    if g then
        prioritise(g.address, "guide")
        return "game"
    end
    local bp = bp_window()
    if bp then
        focus_address(bp.address)
        dismiss_specials("guide -> big picture")
        return "bp"
    end
    log("guide: nothing to go to, launching Big Picture")
    hl.exec_cmd(C.STEAM_LAUNCH .. " steam://open/bigpicture")
    return "launch"
end

function M.stream_event(live)
    apply_game_props(true)
    if live then
        local g = newest_game()
        if g then prioritise(g.address, "stream started") end
    end
    if BP_MONITORS and BP_MONITORS.schedule_evaluate then
        pcall(BP_MONITORS.schedule_evaluate)
    end
    return "ok"
end

function M.user_toggle_special(name)
    last_user_special = os.time()
    hl.dispatch(hl.dsp.workspace.toggle_special(name))
end

function M.status()
    local bp = bp_window()
    return ("bp=%s streaming=%s session=%s games=%d"):format(
        tostring(bp ~= nil), tostring(streaming()), tostring(game_session()),
        #(function() local t = {} for _, w in ipairs(hl.get_windows()) do
            if is_game(w) then t[#t + 1] = w end end return t end)())
end

M.streaming = streaming

BP_FOCUS = M

if not BP_FOCUS_HOOKED then
    BP_FOCUS_HOOKED = true
    local function hook(event, name)
        hl.on(event, function(arg)
            local ok, err = pcall(function() return BP_FOCUS[name](arg) end)
            if not ok then log("handler " .. name .. ": " .. tostring(err)) end
        end)
    end
    hook("window.open", "on_open")
    hook("window.title", "on_title")
    hook("window.close", "on_close")
    hook("window.active", "on_active")
    hook("workspace.special_active", "on_special")
    hook("window.update_rules", "on_rules")
end

for _, key in ipairs({ "SUPER + S", "SUPER + 0" }) do
    pcall(hl.unbind, key)
    hl.bind(key, function() BP_FOCUS.user_toggle_special("magic") end,
        { desc = "Workspaces: Toggle scratchpad (user-intent tracked)" })
end

pcall(apply_game_props, true)
log("loaded; " .. M.status())

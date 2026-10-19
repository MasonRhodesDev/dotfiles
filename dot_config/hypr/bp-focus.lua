-- Steam Big Picture / game focus policy. CONFIG, not a script.
--
-- This replaces the focus half of ~/.config/hypr/scripts/bp-game-focus.py.
-- That daemon drove Hyprland with `hyprctl dispatch focuswindow address:...`,
-- `hyprctl dispatch fullscreen 0` and `hyprctl dispatch togglespecialworkspace`
-- — pre-Lua dispatcher syntax. Since the Lua migration `hyprctl dispatch`
-- EVALUATES ITS ARGUMENT AS LUA, so every one of those calls has failed with
-- exit 7 ("')' expected near ..."), silently, into a log nobody reads. The
-- daemon has therefore focused nothing, fullscreened nothing and dismissed no
-- special workspace for months. Everything it tried to do lives here instead,
-- on the same API the rest of the config uses, so a syntax change cannot rot
-- it without also breaking hyprland.lua itself.
--
-- What this fixes, concretely:
--   1. Special workspaces only ever appear on USER ACTION. Anything else that
--      raises them while Big Picture is up (or a stream is live) is dismissed.
--   2. Steam in-home streaming captures the GAME, not Big Picture. Steam picks
--      its capture target from the host's foreground window; it asks once
--      ("Bringing streamed game to foreground") roughly 3 SECONDS BEFORE the
--      game's window exists in Hyprland, so that request can never land and
--      has failed every time it was logged. We focus the game when its window
--      actually appears, which is what moves the capture.
--   3. Games may raise themselves while Big Picture is up (focusonactivate),
--      so a mid-session raise from Steam works instead of being refused.
--
-- Deliberately NOT here: the gamepad guide button (evdev; no Lua access to
-- input devices) and Steam's CEF log / webhelper chores (not Hyprland's
-- business). Those stay in the daemon, which now asks this module to act
-- rather than dispatching behind its back: BP_FOCUS.guide().

local BP_CLASS = "steam"
local BP_TITLE = "Steam Big Picture Mode"

-- Steam's own Remote Play log. Read on demand (never polled) at the only two
-- moments the answer matters: a game window appearing, and a special
-- workspace appearing.
local STREAM_LOG = os.getenv("HOME") .. "/.local/share/Steam/logs/streaming_log.txt"
local STREAM_TAIL = 8192 -- bytes scanned by the freshness fallback
local STREAM_FRESH = 30  -- s; a marker this recent means a session is live
-- Steam brackets every session with these, perfectly paired and alternating
-- (verified across six sessions in one log). Whichever came last IS the
-- current state, so this needs no freshness window at all.
local STREAM_WINDOW = 524288 -- bytes scanned for the last boundary marker
local STREAM_START  = ">>> Starting desktop stream"
local STREAM_STOP   = ">>> Stopped desktop stream"

local FOCUS_GRACE = 300  -- ms; let a game map and self-fullscreen first
local FOCUS_RETRY = 1200 -- ms; second attempt, for splash -> main window chains
local USER_SPECIAL = 3   -- s; a special toggled by keybind is the user's, hands off

-- Set by the keybinds below. A special workspace becoming visible within
-- USER_SPECIAL seconds of a press is one HE asked for; anything else is an app
-- yanking it up and gets dismissed.
local last_user_special = 0

local function log(msg)
    pcall(hl.exec_cmd, "logger -t hypr-bp-focus '" .. tostring(msg):gsub("'", "") .. "'")
end

----------------------------------------------------------------------
-- STATE ------------------------------------------------------------
----------------------------------------------------------------------

local function bp_window()
    for _, w in ipairs(hl.get_windows()) do
        if w.class == BP_CLASS and w.title == BP_TITLE then return w end
    end
    return nil
end

-- Mirrors the game matching in /usr/share/hypr-de/gaming/game-rules.lua, plus
-- Steam's launch reaper for native games that set their own class (Minecraft
-- via Prism). Lua can read /proc directly, so the ancestry walk the daemon did
-- in Python needs no process of its own.
local LAUNCHER_CLASSES = { ["org.prismlauncher.PrismLauncher"] = true }

-- Memoised per pid: this walk runs from window.title, which fires for every
-- browser tab change and shell prompt, ON THE COMPOSITOR THREAD. Without the
-- cache every one of those pays a /proc walk. Dropped wholesale when it grows,
-- which also bounds the (rare) pid-reuse window.
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
    for _ = 1, 40 do -- ancestry depth guard
        if not pid or pid <= 1 then return remember(false) end
        -- A process that exited mid-walk is a transient miss, NOT cached.
        local f = io.open("/proc/" .. pid .. "/cmdline", "rb")
        if not f then return false end
        local cmdline = f:read("*a") or ""
        f:close()
        if cmdline:find("SteamLaunch", 1, true) then return remember(true) end
        local s = io.open("/proc/" .. pid .. "/stat", "r")
        if not s then return false end
        local stat = s:read("*a") or ""
        s:close()
        -- comm can contain spaces and parens: parse after the LAST ')'
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

-- Latest START-of-session marker in Steam's streaming log, as a unix time, or
-- nil. Only a fallback now: see streaming() for why a freshness window cannot
-- carry this on its own.
local function stream_last_seen()
    local f = io.open(STREAM_LOG, "r")
    if not f then return nil end
    local size = f:seek("end")
    f:seek("set", math.max(0, size - STREAM_TAIL))
    local tail = f:read("*a") or ""
    f:close()

    -- Only timestamps on lines carrying a session marker count; the last one
    -- wins (the tail is in chronological order).
    local latest
    for line in tail:gmatch("[^\n]+") do
        if line:find("Connected UDP@", 1, true)
            or line:find("Maximum capture:", 1, true)
            or line:find("SynchronizeClientState", 1, true) then
            local y, mo, d, h, mi, s =
                line:match("^%[(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)%]")
            if y then
                latest = os.time({
                    year = tonumber(y), month = tonumber(mo), day = tonumber(d),
                    hour = tonumber(h), min = tonumber(mi), sec = tonumber(s),
                })
            end
        end
    end
    return latest
end

-- True if the last stream boundary in the log was a start, nil if the scanned
-- window held no boundary at all.
local function stream_boundary_says_live()
    local f = io.open(STREAM_LOG, "r")
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

-- A freshness window was tried first and does NOT work, because nothing in this
-- log is periodic. The original markers (Connected UDP@, Maximum capture:,
-- SynchronizeClientState) all fire at session start and are then buried by
-- per-frame chatter within seconds. Measured 2026-10-19 during a live stream:
-- zero marker hits in the last 8KB, with the newest marker 426 lines back, so
-- this reported "not streaming" while a stream was running and bp-monitors
-- therefore kept the wrong monitor twice. `dynamicbitrate` is no substitute
-- either: 112 hits during a struggling stream, 0 during a healthy one.
local function streaming()
    local live = stream_boundary_says_live()
    if live ~= nil then return live end
    -- No boundary in the scanned window: a session longer than STREAM_WINDOW of
    -- log, or a log that just rotated. The freshness test at least catches the
    -- opening seconds of a session.
    local seen = stream_last_seen()
    return seen ~= nil and (os.time() - seen) < STREAM_FRESH
end

-- The two conditions under which the game owns the screen and nothing else may
-- take it: Big Picture is up, or a stream is live. "Big Picture is up" means
-- the window EXISTS, not that it has focus — matching bp-monitors.lua, so a
-- game launched from Big Picture keeps priority after BP loses focus.
local function game_session()
    return bp_window() ~= nil or streaming()
end

----------------------------------------------------------------------
-- ACTIONS ----------------------------------------------------------
----------------------------------------------------------------------

local function later(ms, fn)
    hl.timer(function()
        local ok, err = pcall(fn)
        if not ok then log("error: " .. tostring(err)) end
    end, { timeout = ms, type = "oneshot" })
end

local function window_by_address(addr)
    for _, w in ipairs(hl.get_windows()) do
        if w.address == addr then return w end
    end
    return nil
end

-- `focus` wants the selector form; a bare address is "window not found".
local function focus_address(addr)
    hl.dispatch(hl.dsp.focus({ window = "address:" .. addr }))
end

-- action="set" (not the toggle default) so re-asserting is idempotent and can
-- never un-fullscreen something that is already right.
local function fullscreen_on()
    hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen", action = "set" }))
end

-- Dismiss every special workspace currently visible. toggle_special acts on the
-- FOCUSED monitor, so a special shown elsewhere needs that monitor focused
-- first — focus is restored afterwards. (During Big Picture bp-monitors.lua
-- leaves one monitor enabled, so the loop usually runs once.)
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
                -- Name the culprit. What yanks special:magic up on Big Picture
                -- entry was never identified — this is the trace that answers
                -- it on the next occurrence: whoever holds focus at dismissal
                -- time is who grabbed it.
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

-- Let a game honour activation requests while a session is on. The package
-- rule sets focus_on_activate = false so games never steal focus during
-- desktop work; that is right on the desktop and wrong the moment Big Picture
-- is up, which is exactly what he asked to flip. Applied per window with
-- set_prop rather than by redeclaring the rule, so it is observable, reverts
-- cleanly, and does not depend on rule-replacement semantics. Re-applied on
-- window.update_rules because that is when Hyprland rebuilds window data from
-- the rules and drops props set this way.
local function set_focus_on_activate(w, on)
    hl.dispatch(hl.dsp.window.set_prop({
        window = "address:" .. w.address,
        -- Lua prop names are the underscored rule names; "focusonactivate"
        -- (the old hyprctl setprop spelling) is rejected as an invalid prop.
        prop   = "focus_on_activate",
        value  = on and "true" or "false",
    }))
end

-- Only walks the window list when the session state actually FLIPS. It is
-- called from every window open/title/close, and bp-monitors.lua learned the
-- same lesson about unguarded re-evaluation on window events.
local props_applied -- nil = never applied

local function apply_game_props(force)
    local on = game_session()
    if not force and props_applied == on then return end
    props_applied = on
    for _, w in ipairs(hl.get_windows()) do
        if is_game(w) then set_focus_on_activate(w, on) end
    end
    log("games focus_on_activate=" .. tostring(on))
end

-- Bring a game to the front and keep it there. Focus is what Steam's capture
-- follows, so this is the step that makes streaming show the game.
local function prioritise(addr, reason)
    local w = window_by_address(addr)
    if not w then return end
    log("prioritising " .. (w.class or "?") .. " (" .. reason .. ")")
    focus_address(addr)
    dismiss_specials("game priority")
    later(FOCUS_GRACE, function()
        local g = window_by_address(addr)
        if not g then return end
        local aw = hl.get_active_window()
        if not aw or aw.address ~= addr then focus_address(addr) end
        if (g.fullscreen or 0) ~= 2 then fullscreen_on() end
    end)
end

local function newest_game()
    local found
    for _, w in ipairs(hl.get_windows()) do
        if is_game(w) and w.mapped then found = w end
    end
    return found
end

----------------------------------------------------------------------
-- PUBLIC SURFACE ---------------------------------------------------
-- All behaviour hangs off this one global table, and the event hooks are
-- registered EXACTLY ONCE (BP_FOCUS_HOOKED). Re-running this file therefore
-- replaces the logic instead of stacking a second set of handlers on the
-- first, so it can be hot-loaded into a running session with
--   hyprctl eval 'dofile(os.getenv("HOME").."/.config/hypr/bp-focus.lua")'
-- and needs no `hyprctl reload` (which would flap the monitors through
-- bp-monitors.lua, and mid-stream that is visible to the client).
----------------------------------------------------------------------

local M = {}

-- Addresses already brought forward, so one window is never prioritised twice.
-- XWayland sets class/title late, so window.title is a second chance to
-- classify the same window and would otherwise re-fire.
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
    later(FOCUS_RETRY, function() prioritise(w.address, reason .. " retry") end)
end

function M.on_open(w)
    if type(w) == "userdata" then
        M.consider(w, "opened")
    else
        later(FOCUS_GRACE, function() M.consider(newest_game(), "opened") end)
    end
    later(FOCUS_GRACE, apply_game_props)
end

function M.on_title(w)
    if type(w) == "userdata" then M.consider(w, "titled") end
    later(FOCUS_GRACE, apply_game_props)
end

function M.on_close(w)
    if type(w) == "userdata" and w.address then handled[w.address] = nil end
    later(FOCUS_GRACE, apply_game_props)
end

-- Big Picture regaining focus after a fullscreen game exited: Hyprland allows
-- one fullscreen per workspace, so the game had un-fullscreened BP.
function M.on_active(w)
    if type(w) ~= "userdata" then return end
    if w.class == BP_CLASS and w.title == BP_TITLE and (w.fullscreen or 0) ~= 2 then
        fullscreen_on()
    end
end

-- THE special-workspace rule. A special that becomes visible while a session is
-- on and that he did not just toggle is an app raising itself (Discord, Slack
-- and YouTube Music all live on special:magic), or a special migrating off a
-- monitor bp-monitors.lua just disabled. Neither is user action.
function M.on_special()
    local function stray()
        return game_session() and (os.time() - last_user_special) >= USER_SPECIAL
    end
    if not stray() then return end
    later(50, function() if stray() then dismiss_specials("not user-initiated") end end)
end

-- Deliberately NOT a forced re-apply. set_prop ITSELF emits
-- window.update_rules, so forcing here is a feedback loop: apply -> event ->
-- apply (observed hammering one dispatch/second forever). Non-forced means
-- this is a no-op unless the session state actually changed, which breaks the
-- cycle. A genuine rules rebuild is covered by the forced apply at load (a
-- `hyprctl reload` re-runs this file) and by the session edges.
function M.on_rules() later(50, apply_game_props) end

-- The gamepad guide button is the one thing that cannot be config: Lua has no
-- evdev access. bp-game-focus.py calls this instead of dispatching behind our
-- back with a syntax Hyprland stopped understanding.
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
        later(FOCUS_GRACE, function()
            local b = bp_window()
            if b and (b.fullscreen or 0) ~= 2 then fullscreen_on() end
        end)
        return "bp"
    end
    return "none" -- daemon launches Big Picture; on_open brings it forward
end

-- Called by the daemon when it sees a stream start, so a game already running
-- in the background is pulled forward instead of waiting for a new window.
function M.stream_started()
    apply_game_props(true)
    local g = newest_game()
    if g then prioritise(g.address, "stream started") end
    -- bp-monitors keeps a DIFFERENT monitor while streaming (16:9 instead of
    -- the ultrawide), and it only re-evaluates on window and monitor events. A
    -- stream that begins while Big Picture is already up produces neither, so
    -- poke it. Guarded because a machine that does not deploy bp-monitors
    -- leaves the global nil.
    if BP_MONITORS and BP_MONITORS.schedule_evaluate then
        pcall(BP_MONITORS.schedule_evaluate)
    end
    return "ok"
end

-- Records intent, then does what the package bind did. A special opened this
-- way is his, and M.on_special leaves it alone.
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

-- bp-monitors asks this to decide which monitor to keep. Exposed rather than
-- duplicated: the log tail parser and its freshness window live here only.
M.streaming = streaming

BP_FOCUS = M

----------------------------------------------------------------------
-- HOOKS (once) + BINDS ---------------------------------------------
-- Every handler goes through the global table and is wrapped in pcall, so one
-- bad event can never take the chain (or the config) down with it.
----------------------------------------------------------------------

if not BP_FOCUS_HOOKED then
    BP_FOCUS_HOOKED = true
    -- If `hyprctl reload` does NOT wipe Lua globals, this flag would survive
    -- and the reloaded module would register no hooks at all — silently inert,
    -- the exact failure mode that hid the broken daemon for months. Clearing it
    -- on unload makes re-hooking correct either way.
    hl.on("config.unload", function() BP_FOCUS_HOOKED = nil end)
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

-- The scratchpad binds from main.lua, wrapped so a press records intent.
-- hl.bind APPENDS, so the package binds are dropped first (same pattern as the
-- monitor-direction swap in local.lua).
for _, key in ipairs({ "SUPER + S", "SUPER + 0" }) do
    pcall(hl.unbind, key)
    hl.bind(key, function() BP_FOCUS.user_toggle_special("magic") end,
        { desc = "Workspaces: Toggle scratchpad (user-intent tracked)" })
end

-- Resync at load (and on reload, which rebuilds this Lua state).
pcall(apply_game_props, true)
log("loaded; " .. M.status())

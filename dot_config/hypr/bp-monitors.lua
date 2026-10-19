-- Steam Big Picture and Remote Play monitor override. Desktop-only (see
-- .chezmoiignore); loaded from local.lua, and it no-ops on any machine without
-- KEEP_DESC.
--
-- A locked state machine with three states, each more specific than the last:
--
--   NORMAL  every monitor as the desk profile has it
--   BP      Big Picture window exists: keep the ultrawide, disable the rest
--   STREAM  a Remote Play session is live: keep the largest 16:9 panel instead
--
-- Entry is immediate and locks the state. Nothing inside a state re-evaluates
-- which monitor to keep; that was decided once, on entry, from a snapshot taken
-- before anything was disabled. A state is left only when its own exit
-- criterion holds, and the exit criteria are deliberately narrow:
--
--   NORMAL -> BP      a Big Picture window appears        (window.open/title)
--   BP     -> STREAM  a session is live                   (stream edge from the daemon)
--   BP     -> NORMAL  Big Picture is gone                 (window.close), unless held
--   STREAM -> NORMAL  the session is over (stream edge), once Steam has
--                     closed the Big Picture window it raised (window.close)
--
-- Every transition is driven by an event. There are no polls and no settle
-- or grace delays: the only timers are FAILURE paths, each with a name, each
-- logging a WARNING when it fires, because firing means an event that should
-- have arrived did not. A 50ms coalesce on event bursts is the one exception
-- and it waits for nothing; a game launch retitles its window dozens of times
-- a second and one evaluate per burst is plenty.
--
-- "Held": the daemon restarts Steam to recover from a CEF crash storm, which
-- closes and reopens Big Picture. It says so (BP_MONITORS.hold(true/false))
-- around the restart, and BP stays locked through it instead of flapping the
-- monitors. Without that signal, Big Picture closing releases at once.
--
-- A session ending exits all the way to NORMAL, never back to BP. A remote
-- client raises a Big Picture window on this host that nobody here opened,
-- and Steam closes it itself about 8s after the client disconnects (measured
-- 2026-10-19 15:58:51 to 15:58:59, nobody at the desk). Releasing before
-- that re-enters BP on the lingering window and leaves the desk on one
-- monitor, which is what happened at 13:50 the same day. So session end
-- waits for that window.close and only then releases, which keeps the rest
-- generic: no per-window bookkeeping, and the ordinary BP entry and exit
-- rules stay the only ones. A compositor close request was tried first and
-- Steam ignores it. Should Steam keep the window past BP_EXIT_MAX_MS we
-- release anyway, log a WARNING, and the normal rule re-enters BP on it;
-- that is visible in the journal rather than hidden behind an ignore list.
--
-- STREAM is reachable only from BP. A session with no Big Picture window
-- leaves the monitors alone. Window title and open/close events, which storm
-- while a game launches, are no-ops in STREAM because they are not its exit
-- criterion. The previous design re-derived the kept monitor on every event
-- and released whenever the answer changed, which flapped the displays each
-- time a title started.
--
-- Changing the kept monitor (BP <-> STREAM) cannot be done in place: enabling
-- the 16:9 panel while the ultrawide is still on makes hyprstate match the
-- full desk profile, which re-enables everything and leaves the panel in
-- portrait. The only intermediate layout with known behaviour is "everything
-- on", so the switch releases, waits for every snapshot monitor to be enabled
-- again, then applies the new override. One visible flap per switch.
--
-- Rotation and the kept monitor's geometry belong to hyprstate. With the
-- others disabled, exactly one profile matches the remaining set (ultrawide-
-- only for BP, stream-16x9 for STREAM) and hyprstate selects it on the
-- topology change, verified unprompted on 2026-10-19. NEVER request a profile
-- from here: applying one re-enables every monitor it does not mention, which
-- lands back in this module and loops.
--
-- The disable rides on the same rule name the active profile uses for that
-- monitor (parsed from profiles/.active.lua), so hl.monitor's merge-by-name
-- keeps position, scale and transform, and re-enabling is just disabled=false.
--
-- `hyprctl reload` wipes this state and re-applies the current profile, which
-- re-enables every monitor that profile does not mention. The load-time
-- evaluate then enters the most specific applicable state directly from a
-- complete snapshot. One flap on a reload mid-override, then correct.

local C = BP_COMMON or dofile((os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/bp-common.lua")

-- The monitor Big Picture keeps is the same one hypr-DE makes the XWayland
-- primary, read from that knob file so there is one definition of "the
-- gaming monitor" on this machine. The knob holds a model substring
-- ("S3422DWG"); it is matched against the EDID description here and against
-- hyprctl's model field there. BP_KEEP_MONITOR_DESC overrides for a test.
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
-- Without a keep monitor, BP is a no-op (never blank the desk on a guess) and
-- STREAM still keeps the largest 16:9 panel. Said once at load so a machine
-- that forgot the knob file does not look like a silent failure.


-- Event bursts (a launching game retitles constantly) collapse to one
-- evaluate. This waits for nothing: it is the gap between two events.
local COALESCE_MS    = 50

-- FAILURE timeouts. None of these is part of a normal cycle; each one firing
-- is logged as a WARNING because it means an event never arrived.
local BP_EXIT_MAX_MS = 15000 -- Steam did not close Big Picture after a session ended (it takes ~8s)
local PENDING_MAX_MS = 6000  -- a monitor never came back during a BP <-> STREAM switch
local RELEASE_MAX_MS = 6000  -- a monitor never came back after a release
local HOLD_MAX_MS    = 90000 -- the daemon said "restarting Steam" and never said done
local SAFETY_MS      = 30000 -- an exit criterion was met and no event reported it

local S_NORMAL, S_BP, S_STREAM = "NORMAL", "BP", "STREAM"

local state     = S_NORMAL
local pending   = nil  -- state to enter once every snapshot monitor is enabled
local kept      = nil  -- snapshot entry the current override keeps
local snapshot  = {}   -- { name, key, w, h, keep } taken before anything was disabled
local disabled  = {}   -- { { rule = "desc:...", key = mon_key } }
local homes     = {}   -- workspace id -> mon_key of the monitor it lived on
local closing   = nil  -- address of the Big Picture window Steam is expected to close
local held      = false -- daemon is restarting Steam; BP must not release
local held_logged = false
local releasing = nil  -- { homes = {...}, keys = {...} } until every monitor is back
local desk      = nil  -- { rules = { [rule] = "{ output = ... }" }, ws = { [id] = selector } } from the profile at snapshot time
local eval_gen  = 0

local sh_quote = C.sh_quote
local log = C.logger("hypr-bp-monitors")
if not KEEP_DESC then log("no keep monitor configured (hypr-de/xwayland-primary); Big Picture leaves monitors alone") end

local function has_prefix(s, p)
    return type(s) == "string" and p ~= "" and s:sub(1, #p) == p
end

-- Identity for a monitor: its EDID description, or the connector name when it
-- has none (virtual outputs). An empty description must never become a
-- "desc:" selector, which would match every monitor.
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

-- A named one-shot timer: arming replaces the previous arming, cancel drops
-- it. One per failure path, so a state change cancels exactly the timeouts
-- that no longer apply.
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
local t_state   = timer() -- pending switch, close wait, hold: one per state
local t_release = timer()
local t_safety  = timer()

-- The active profile's monitor rules, verbatim, keyed by their output
-- selector ("desc:Dell Inc. DELL S2721QS", ...), plus its workspace rules.
-- Taken at snapshot time, when the active profile is the desk layout, so a
-- release can put every monitor back exactly where that profile has it in
-- one pass. hyprstate then finds the desk set already in its own layout and
-- its re-apply is a no-op; before this, the kept monitor sat at the stream
-- profile's 0,0 landscape while the others came back on top of it, and
-- Hyprland warned about the overlap until hyprstate caught up.
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

-- Same rule the profile applies to this monitor, so disabled=true/false merges
-- into it. A monitor the profile doesn't mention gets its own exact-desc rule.
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

-- hl.get_monitors() does not report a monitor we disabled, so the candidates
-- are captured while everything is still enabled and reused for the whole
-- override, including a BP <-> STREAM switch.
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

-- Largest 16:9 area the panel can show, from its MODE. hl.get_monitors()
-- reports the mode, not the rotated logical size: the portrait S2721QS reads
-- 3840x2160 with transform 3. A 21:9 panel is bounded by its height, a taller
-- one by its width.
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

-- Remote Play clients are 16:9 and the ultrawide is 21:9, so keeping the
-- ultrawide while streaming wastes most of the panel inside a 16:9 frame.
-- Ties go to KEEP_DESC so desk behaviour never turns on a coin flip.
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

-- Disable every enabled monitor except `keep`. Returns false if there was
-- nothing to do, which means someone else shaped the layout and we would have
-- nothing to re-enable later.
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

    -- Where workspaces live NOW, before Hyprland evacuates them onto `keep`.
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
    -- XWayland primary: hypr-de's listener resolves its knob (a model substring)
    -- against `hyprctl monitors -j`, which lists only ENABLED monitors, so with
    -- the ultrawide disabled it matches nothing and leaves primary on a dead
    -- output. Steam reads primary to size the desktop it captures.
    hl.exec_cmd("xrandr --output " .. sh_quote(keep.name) .. " --primary")
    return true
end

-- The monitor a workspace belongs on: the profile's workspace rule when it
-- has one (the rule wins over wherever the workspace happened to be when the
-- override began, which was often the kept monitor it had been evacuated to),
-- else where it was observed.
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

-- After a release, once the monitors are back: move workspaces home (Hyprland
-- usually does this itself; this only moves one that is not already home)
-- and hand XWayland primary back to hypr-de's own knob.
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

-- Put every monitor back as the desk profile has it, in one pass: the kept
-- monitor's geometry first (it may be sitting in the stream profile's
-- landscape 0,0), then the ones we disabled. A rule the profile does not
-- carry (a monitor it never mentions) is just re-enabled. The re-enable lands
-- asynchronously and fires monitor.layout_changed, which completes it in
-- evaluate().
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

local evaluate -- forward

-- The safety check is a failure path, not a poll: if it ever changes state,
-- the exit criterion was met and no event told us. Re-armed while an override
-- is active so the next miss is caught too.
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
        -- Never blank the desk on a guess. Stay in NORMAL and try again on
        -- the next event.
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

-- Session over: Steam closes the Big Picture window itself. Its window.close
-- event completes the exit in evaluate(); releasing while it is still up
-- would re-enter BP on the next event.
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

-- Switching kept monitors goes through "everything on" (see header). The
-- re-enable fires monitor.layout_changed, which brings us back here with
-- pending set; we apply once every snapshot monitor is visible again.
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

    -- The kept monitor went away mid-override: never leave the desk blank.
    -- Checked against LIVE monitors; the snapshot still lists it.
    if kept and not monitor_by_key(kept.key) then
        to_normal("kept monitor " .. kept.key .. " is gone")
        return
    end

    if pending then
        if all_enabled(snapshot_keys()) then enter(pending) end
        return
    end

    if state == S_NORMAL then
        if not bp_present() then return end
        take_snapshot()
        -- Enter the most specific applicable state directly. After a reload
        -- mid-stream this is STREAM, with no detour through BP.
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

-- The daemon brackets a crash-recovery Steam restart with hold(true) and
-- hold(false). HOLD_MAX_MS is the failure path for a daemon that died between
-- the two.
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

-- XWayland sets the title late, so window.title matters as much as window.open.
hl.on("window.open",    function() schedule_evaluate() end)
hl.on("window.title",   function() schedule_evaluate() end)
hl.on("window.close",   function() schedule_evaluate() end)
hl.on("window.destroy", function() schedule_evaluate() end)
hl.on("monitor.added",   function() schedule_evaluate() end)
hl.on("monitor.removed", function() schedule_evaluate() end)
-- A monitor re-enabled by RULE is not a monitor.added, but it does change the
-- layout. This is the event that completes a release or a pending switch, and
-- the one that lets a reload mid-override recover (config.reloaded never
-- reaches a handler registered during that same load, verified).
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

-- schedule_evaluate: bp-focus pokes it on a stream edge, since no window or
-- monitor event fires then. hold: see above. status: read the locked state
-- without guessing from monitor shape; surface it with `hyprctl eval` into a
-- file.
BP_MONITORS = { schedule_evaluate = schedule_evaluate, hold = hold, status = status }

local ok, err = pcall(evaluate)
if not ok then log("error at load: " .. tostring(err)) end
schedule_evaluate()

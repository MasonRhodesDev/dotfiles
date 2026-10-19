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
--   NORMAL -> BP      a Big Picture window appears
--   BP     -> STREAM  a session is live
--   BP     -> NORMAL  Big Picture has been gone for REVERT_MS
--   STREAM -> BP      the session has been over for STREAM_EXIT_MS and BP remains
--   STREAM -> NORMAL  the session has been over for STREAM_EXIT_MS and BP is gone
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

local KEEP_DESC = os.getenv("BP_KEEP_MONITOR_DESC") or "Dell Inc. DELL S3422DWG"
local BP_CLASS  = "steam"
local BP_TITLE  = "Steam Big Picture Mode"

local SETTLE_MS      = 1500  -- window/monitor event -> evaluate
local POLL_MS        = 10000 -- BP and STREAM re-check their exit criterion
-- Steam's crash-storm recovery (bp-game-focus.py) restarts it: up to ~30s
-- shutdown plus relaunch. 8s means a restart flaps the monitors once; that is
-- accepted rather than holding the second monitors off for a minute.
local REVERT_MS      = 8000
-- Session end is read from Steam's log, so give it a moment to be sure rather
-- than release on the first false reading.
local STREAM_EXIT_MS = 5000
-- After re-enable, move workspaces back to the monitor they lived on. Hyprland
-- normally does this itself when the monitor returns (observed); this is the
-- backstop, and it only moves a workspace that is not already home.
local REHOME_MS      = 2500
-- A pending switch waits for every snapshot monitor to come back. If one never
-- does (cable pulled mid-switch), proceed with what is enabled rather than
-- parking the machine.
local PENDING_MAX_MS = 6000

local S_NORMAL, S_BP, S_STREAM = "NORMAL", "BP", "STREAM"

local state     = S_NORMAL
local pending   = nil  -- state to enter once every snapshot monitor is enabled
local kept      = nil  -- snapshot entry the current override keeps
local snapshot  = {}   -- { name, key, w, h, keep } taken before anything was disabled
local disabled  = {}   -- { { rule = "desc:...", key = mon_key } }
local homes     = {}   -- workspace id -> mon_key of the monitor it lived on
local eval_gen  = 0
local timer_gen = 0    -- the single exit/poll/pending timer; re-arming cancels the old one

local function sh_quote(s)
    return "'" .. (tostring(s):gsub("'", "'\\''")) .. "'"
end

-- The "--" matters: logger parses an argument that begins with a dash as an
-- option and rejects the whole line, so every "-> STATE" transition message
-- was silently dropped until 2026-10-19. The pcall hid the failure.
local function log(msg)
    pcall(hl.exec_cmd, "logger -t hypr-bp-monitors -- " .. sh_quote(msg))
end

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
    return m.name == KEEP_DESC or has_prefix(m.description, KEEP_DESC)
end

local function streaming()
    if not (BP_FOCUS and BP_FOCUS.streaming) then return false end
    local ok, live = pcall(BP_FOCUS.streaming)
    return ok and live == true
end

local function later(ms, fn)
    hl.timer(function()
        local ok, err = pcall(fn)
        if not ok then log("error: " .. tostring(err)) end
    end, { timeout = ms, type = "oneshot" })
end

-- One timer at a time. Arming cancels whatever was armed before, so a
-- transition never races a stale poll or revert from the previous state.
local function arm(ms, fn)
    timer_gen = timer_gen + 1
    local mine = timer_gen
    later(ms, function()
        if mine == timer_gen then fn() end
    end)
end

-- The rule names the active profile uses ("desc:Dell Inc. DELL S2721QS", ...).
local function profile_rule_names()
    local names = {}
    local base = os.getenv("XDG_CONFIG_HOME")
    if not base or base == "" then base = os.getenv("HOME") .. "/.config" end
    local f = io.open(base .. "/hypr/profiles/.active.lua", "r")
    if not f then return names end
    local text = f:read("*a")
    f:close()
    for out in text:gmatch('hl%.monitor%(%s*{[^}]-output%s*=%s*"([^"]+)"') do
        names[#names + 1] = out
    end
    return names
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

local function bp_present()
    for _, w in ipairs(hl.get_windows()) do
        if w.class == BP_CLASS and w.title == BP_TITLE then return true end
    end
    return false
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
    for _, m in ipairs(hl.get_monitors()) do
        if m.enabled then
            snapshot[#snapshot + 1] = { name = m.name, key = mon_key(m),
                                        w = m.width, h = m.height, keep = is_keep(m) }
        end
    end
end

local function all_snapshot_enabled()
    for _, c in ipairs(snapshot) do
        if not monitor_by_key(c.key) then return false end
    end
    return #snapshot > 0
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

local function rehome(pending_homes)
    if kept then return end -- an override came back before we got here
    for id, key in pairs(pending_homes) do
        local mon = monitor_by_key(key)
        local ws  = hl.get_workspace(id)
        if mon and ws and (not ws.monitor or ws.monitor.name ~= mon.name) then
            hl.dispatch(hl.dsp.workspace.move({ workspace = id, monitor = mon.name }))
            log("re-homed workspace " .. id .. " to " .. key)
        end
    end
end

local function release()
    for _, d in ipairs(disabled) do
        hl.monitor({ output = d.rule, disabled = false })
        log("re-enabled " .. d.key .. " via " .. d.rule)
    end
    local pending_homes = homes
    disabled, homes, kept = {}, {}, nil
    later(REHOME_MS, function() rehome(pending_homes) end)
    -- Hand XWayland primary back to hypr-de's own knob. Deferred because the
    -- re-enable has not landed yet and the script sees only enabled monitors.
    later(REHOME_MS, function() hl.exec_cmd("/usr/lib/hypr-de/set-xwayland-primary.sh") end)
end

local evaluate -- forward, the timers below call it

local function enter(target)
    local keep = (target == S_STREAM) and choose_stream() or choose_bp()
    if not apply_override(keep) then
        -- Never blank the desk on a guess. Stay in NORMAL and try again on
        -- the next event.
        state, pending = S_NORMAL, nil
        return
    end
    state, pending = target, nil
    log("-> " .. state .. " keeping " .. keep.key)
    arm(POLL_MS, evaluate)
end

local function to_normal(why)
    release()
    state, pending, snapshot = S_NORMAL, nil, {}
    timer_gen = timer_gen + 1 -- NORMAL is event driven; drop any poll
    log("-> NORMAL (" .. why .. ")")
end

-- Switching kept monitors goes through "everything on" (see header). The
-- re-enable fires monitor.layout_changed, which brings us back here with
-- pending set; we apply once every snapshot monitor is visible again.
local function switch_to(target)
    release()
    pending = target
    log("-> " .. target .. " pending; released, waiting for all monitors")
    arm(PENDING_MAX_MS, function()
        if pending == target then
            log("pending " .. target .. " timed out; applying with what is enabled")
            enter(target)
        end
    end)
end

evaluate = function()
    -- The kept monitor went away mid-override: never leave the desk blank.
    -- Checked against LIVE monitors; the snapshot still lists it.
    if kept and not monitor_by_key(kept.key) then
        to_normal("kept monitor " .. kept.key .. " is gone")
        return
    end

    if pending then
        if all_snapshot_enabled() then enter(pending) end
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
            arm(REVERT_MS, function()
                if state == S_BP and not bp_present() then
                    to_normal("Big Picture gone")
                else
                    arm(POLL_MS, evaluate)
                end
            end)
        else
            arm(POLL_MS, evaluate)
        end

    elseif state == S_STREAM then
        if streaming() then
            arm(POLL_MS, evaluate)
        else
            arm(STREAM_EXIT_MS, function()
                if state ~= S_STREAM then return end
                if streaming() then
                    arm(POLL_MS, evaluate)
                elseif bp_present() then
                    switch_to(S_BP)
                else
                    to_normal("session over, Big Picture gone")
                end
            end)
        end
    end
end

local function schedule_evaluate()
    eval_gen = eval_gen + 1
    local mine = eval_gen
    later(SETTLE_MS, function()
        if mine == eval_gen then evaluate() end
    end)
end

-- XWayland sets the title late, so window.title matters as much as window.open.
hl.on("window.open",    function() schedule_evaluate() end)
hl.on("window.title",   function() schedule_evaluate() end)
hl.on("window.close",   function() schedule_evaluate() end)
hl.on("window.destroy", function() schedule_evaluate() end)
hl.on("monitor.added",   function() schedule_evaluate() end)
hl.on("monitor.removed", function() schedule_evaluate() end)
-- A monitor re-enabled by RULE is not a monitor.added, but it does change the
-- layout. This is the event that completes a pending switch, and the one that
-- lets a reload mid-override recover (config.reloaded never reaches a handler
-- registered during that same load, verified).
hl.on("monitor.layout_changed", function() schedule_evaluate() end)

-- bp-focus pokes this when a session starts: no window or monitor event fires
-- at that moment, and BP's exit criterion has just been met.
local function status()
    local snap = {}
    for _, c in ipairs(snapshot) do snap[#snap + 1] = c.name end
    local dis = {}
    for _, d in ipairs(disabled) do dis[#dis + 1] = d.key end
    return ("state=%s pending=%s kept=%s snapshot=[%s] disabled=[%s] bp=%s streaming=%s"):format(
        state, tostring(pending), kept and kept.name or "nil",
        table.concat(snap, ","), table.concat(dis, ","),
        tostring(bp_present()), tostring(streaming()))
end

-- schedule_evaluate: bp-focus pokes it when a session starts, since no window
-- or monitor event fires then. status: read the locked state without guessing
-- from monitor shape; surface it with `hyprctl eval` into a file.
BP_MONITORS = { schedule_evaluate = schedule_evaluate, status = status }

local ok, err = pcall(evaluate)
if not ok then log("error at load: " .. tostring(err)) end
schedule_evaluate()

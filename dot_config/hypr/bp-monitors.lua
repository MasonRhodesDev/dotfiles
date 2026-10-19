-- Steam Big Picture => ultrawide only. Desktop-only (see .chezmoiignore);
-- loaded from local.lua, and it no-ops on any machine without KEEP_DESC.
--
-- While a Big Picture window exists, every enabled monitor except the
-- ultrawide is disabled; a few seconds after the window is gone they are
-- re-enabled and the workspaces that lived on them are moved back. "Running"
-- means the window EXISTS, not that it has focus, so games launched from Big
-- Picture keep the override until Big Picture itself closes.
--
-- Not a profile: hyprstate keeps choosing profiles from the live monitor set
-- and will see the disable/enable as an ordinary topology change (it applies
-- ultrawide-only, then the full profile again on exit). The disable rides on
-- the SAME rule name the profile uses for that monitor (parsed from
-- profiles/.active.lua), so hl.monitor's merge-by-name keeps position, scale
-- and transform and re-enabling is just disabled=false.
--
-- `hyprctl reload` rebuilds the Lua state and clears the monitor rules, so
-- state here dies on reload; the resync at the bottom re-applies the override
-- if Big Picture is still open.

local KEEP_DESC = os.getenv("BP_KEEP_MONITOR_DESC") or "Dell Inc. DELL S3422DWG"
local BP_CLASS  = "steam"
local BP_TITLE  = "Steam Big Picture Mode"

local SETTLE_MS = 1500 -- window/monitor events -> re-evaluate
-- Steam's crash-storm recovery (bp-game-focus.py) restarts it: up to ~30s
-- shutdown plus relaunch. 8s means a restart flaps the monitors once; that is
-- accepted rather than holding the second monitors off for a minute.
local REVERT_MS = 8000
-- After re-enable, move workspaces back to the monitor they lived on. Hyprland
-- normally does this itself when the monitor returns (observed); this is the
-- backstop, and it only moves a workspace that is not already home.
local REHOME_MS = 2500
-- Streaming state comes from a log tail with a freshness window, so no event
-- announces a stream ENDING. While one is live, re-check on a timer; the poll
-- stops rescheduling as soon as streaming goes false.
local STREAM_POLL_MS = 10000

local active      = false -- override currently applied
local disabled    = {}    -- { { rule = "desc:...", key = mon_key } }
local homes       = {}    -- workspace id -> mon_key of the monitor it lived on
local eval_gen    = 0
local revert_gen  = 0
local stream_gen  = 0
local active_key  = nil  -- mon_key of the monitor the active override kept
-- Candidate monitors as they were BEFORE the override disabled anything:
-- { name, key, w, h, keep }. hl.get_monitors() does not report a monitor we
-- disabled, so once the override is applied the alternatives are invisible and
-- the kept monitor could never be reconsidered. Verified 2026-10-19: a stream
-- that began one second after the override was applied left bp-monitors on the
-- ultrawide, because by then DP-1 was no longer in get_monitors().
local candidates  = {}

local function sh_quote(s)
    return "'" .. (tostring(s):gsub("'", "'\\''")) .. "'"
end

local function log(msg)
    pcall(hl.exec_cmd, "logger -t hypr-bp-monitors " .. sh_quote(msg))
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

-- Largest 16:9 area the panel can show, computed from its MODE. hl.get_monitors()
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

-- The candidate set: the pre-override snapshot while an override is active,
-- otherwise the live monitors. Returns plain tables either way so callers
-- cannot accidentally depend on userdata accessors.
local function candidate_list()
    if active and #candidates > 0 then return candidates end
    local out = {}
    for _, m in ipairs(hl.get_monitors()) do
        if m.enabled then
            out[#out + 1] = { name = m.name, key = mon_key(m),
                              w = m.width, h = m.height, keep = is_keep(m) }
        end
    end
    return out
end

-- Remote Play clients are 16:9 and the ultrawide is 21:9, so keeping the
-- ultrawide while streaming wastes most of the panel inside a 16:9 frame.
-- Ties go to KEEP_DESC so desk behaviour never turns on a coin flip.
local function best_16x9()
    local best, best_area = nil, -1
    for _, c in ipairs(candidate_list()) do
        local a = area_16x9(c)
        if a > best_area or (a == best_area and c.keep) then
            best, best_area = c, a
        end
    end
    return best
end

local function later(ms, fn)
    hl.timer(function()
        local ok, err = pcall(fn)
        if not ok then log("error: " .. tostring(err)) end
    end, { timeout = ms, type = "oneshot" })
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

-- Desk use keeps the ultrawide. Streaming keeps whichever panel gives the most
-- 16:9 pixels; on this desk that is the S2721QS, which sits portrait here and
-- is rotated to landscape by the `stream-16x9` hyprstate profile once it
-- becomes the only enabled monitor.
local function keep_monitor()
    if streaming() then
        local c = best_16x9()
        if c then return c end
    end
    for _, c in ipairs(candidate_list()) do
        if c.keep then return c end
    end
    return nil
end

local function monitor_by_key(key)
    for _, m in ipairs(hl.get_monitors()) do
        if m.enabled and mon_key(m) == key then return m end
    end
    return nil
end

-- Idempotent: only touches monitors that are enabled right now, so calling it
-- again picks up a monitor plugged in (or woken) during Big Picture.
local function disable_others()
    -- Snapshot BEFORE choosing, while every monitor is still enabled and
    -- therefore still visible to hl.get_monitors(). Only refreshed when no
    -- override is active, so a mid-override re-pick still sees the full set.
    if not active then
        candidates = {}
        for _, m in ipairs(hl.get_monitors()) do
            if m.enabled then
                candidates[#candidates + 1] = { name = m.name, key = mon_key(m),
                                                w = m.width, h = m.height,
                                                keep = is_keep(m) }
            end
        end
    end

    local keep = keep_monitor()
    if not keep then return end -- never blank the desktop without the ultrawide

    local targets = {}
    for _, m in ipairs(hl.get_monitors()) do
        if m.enabled and m.name ~= keep.name then targets[#targets + 1] = m end
    end
    if #targets == 0 then return end

    -- Where workspaces live NOW, before Hyprland evacuates them onto the ultrawide.
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
    active_key = keep.key
    -- XWayland primary: hypr-de's listener resolves its knob (a model substring)
    -- against `hyprctl monitors -j`, which lists only ENABLED monitors, so with
    -- the ultrawide disabled it matches nothing and leaves primary pointing at a
    -- dead output. Steam reads primary to size the desktop it captures, so aim
    -- it at the monitor we kept.
    hl.exec_cmd("xrandr --output " .. sh_quote(keep.name) .. " --primary")
    log("kept " .. active_key .. " (streaming=" .. tostring(streaming())
        .. "); xwayland primary -> " .. keep.name)
    active = true
end

local function rehome(pending)
    if active then return end -- Big Picture came back before we got here
    for id, key in pairs(pending) do
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
    local pending = homes
    disabled, homes, active, active_key, candidates = {}, {}, false, nil, {}
    later(REHOME_MS, function() rehome(pending) end)
    -- Hand XWayland primary back to hypr-de's own knob rather than guessing it.
    -- Deferred because the re-enable above has not landed yet, and the script
    -- can only see monitors that are already enabled.
    later(REHOME_MS, function() hl.exec_cmd("/usr/lib/hypr-de/set-xwayland-primary.sh") end)
end

local function evaluate()
    -- The kept monitor went away mid-override: never leave the desktop blank.
    -- Checked against LIVE monitors, not the snapshot, which still lists a
    -- monitor that has since been unplugged.
    if active and active_key and not monitor_by_key(active_key) then
        log("kept monitor " .. active_key .. " is gone; releasing override")
        release()
        return
    end

    -- The right monitor to keep differs between desk use and streaming, so a
    -- stream starting or ending mid-override changes the target. disable_others()
    -- only ever disables, so switching means releasing first and letting the
    -- resulting monitor.layout_changed bring us back through here with every
    -- monitor visible again. Re-applying inline instead would race the
    -- re-enable and re-pick the monitor we were trying to leave.
    if active and active_key and bp_present() then
        local want = keep_monitor()
        if want and want.key ~= active_key then
            log("keep should be " .. want.key .. " not " .. active_key
                .. " (streaming=" .. tostring(streaming()) .. "); releasing to re-pick")
            release()
            return
        end
    end

    if bp_present() then
        revert_gen = revert_gen + 1 -- cancels any pending revert
        disable_others()
        -- Re-check on a timer for as long as Big Picture is up, NOT only while
        -- streaming. A stream's first log marker can land a fraction of a
        -- second after this evaluate runs (measured: override at 13:08:16.0,
        -- marker at 13:08:16.04), so gating the poll on streaming() meant a
        -- lost race was never revisited.
        stream_gen = stream_gen + 1
        local mine = stream_gen
        later(STREAM_POLL_MS, function()
            if mine == stream_gen then evaluate() end
        end)
    elseif active then
        revert_gen = revert_gen + 1
        local mine = revert_gen
        later(REVERT_MS, function()
            if mine == revert_gen and active and not bp_present() then release() end
        end)
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
-- Not gated on `active`: after a reload the fresh profile rules re-enable the
-- monitors WE had disabled, and that monitor.added is what tells us to disable
-- them again. It is also how a monitor woken/plugged in during Big Picture, or
-- the ultrawide dropping out, is noticed. With no Big Picture it is a no-op.
hl.on("monitor.added",   function() schedule_evaluate() end)
hl.on("monitor.removed", function() schedule_evaluate() end)

-- Resync at load. A reload wipes the rules, but at this instant Hyprland still
-- reports the monitors we had disabled as disabled (the fresh rules re-enable
-- them a moment later), so there is nothing to act on yet: the monitor.added
-- events above do the work, and this deferred pass is the backstop.
-- A reload DURING Big Picture used to lose the override, verified 2026-10-18
-- with a clean `hyprctl reload`: the fresh profile rules re-enabled DP-1 and
-- HDMI-A-1 and nothing disabled them again — no log line at all, so neither
-- the monitor.added handlers nor the deferred backstop below ran. Re-enabling a
-- monitor by RULE is not a monitor.added, and a timer scheduled while the
-- config is still being parsed does not survive the end of that load.
-- The fix has to be an event that fires BY ITSELF after the reload. Tried and
-- rejected: config.reloaded never reached a handler registered during that same
-- load (verified with a clean reload — no log line). monitor.added does not fire
-- for a monitor re-enabled by RULE. The window.* hooks above are registered
-- fine but nothing was opening or retitling windows, so nothing woke them.
-- Enabling an output DOES change the layout, so this is the signal that cannot
-- be missed. Converges rather than loops: our own disable_others() changes the
-- layout too, but the next pass finds the other monitors already disabled, so
-- targets is empty and it returns without touching anything.
hl.on("monitor.layout_changed", function() schedule_evaluate() end)

-- bp-focus pokes this when a stream starts: no window or monitor event fires at
-- that moment, yet the monitor we should keep has just changed.
BP_MONITORS = { schedule_evaluate = schedule_evaluate }

local ok, err = pcall(evaluate)
if not ok then log("error at load: " .. tostring(err)) end
schedule_evaluate()

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

local active      = false -- override currently applied
local disabled    = {}    -- { { rule = "desc:...", key = mon_key } }
local homes       = {}    -- workspace id -> mon_key of the monitor it lived on
local eval_gen    = 0
local revert_gen  = 0

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

local function keep_monitor()
    for _, m in ipairs(hl.get_monitors()) do
        if m.enabled and is_keep(m) then return m end
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
    disabled, homes, active = {}, {}, false
    later(REHOME_MS, function() rehome(pending) end)
end

local function evaluate()
    if active and not keep_monitor() then
        -- The ultrawide went away mid-override: never leave the desktop blank.
        log("ultrawide gone; releasing override")
        release()
        return
    end

    if bp_present() then
        revert_gen = revert_gen + 1 -- cancels any pending revert
        disable_others()
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
local ok, err = pcall(evaluate)
if not ok then log("error at load: " .. tostring(err)) end
schedule_evaluate()

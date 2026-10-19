-- Shared by bp-focus.lua and bp-monitors.lua. CONFIG, not a script.
--
-- One definition each of: where the config lives, what a Big Picture window
-- is, how to log, and how to run something later. Both modules used to carry
-- their own copies; the copies drifted (one log() kept a bug the other had
-- fixed), which is the whole reason this file exists.
--
-- Loaded with dofile by each module, guarded so a second load is a no-op and
-- a hot reload of one module never rebuilds the other's helpers.

if BP_COMMON then return BP_COMMON end

local M = {}

M.CONFIG_BASE = os.getenv("XDG_CONFIG_HOME")
if not M.CONFIG_BASE or M.CONFIG_BASE == "" then
    M.CONFIG_BASE = os.getenv("HOME") .. "/.config"
end

M.BP_CLASS = "steam"
M.BP_TITLE = "Steam Big Picture Mode"

function M.is_bp(w)
    return w ~= nil and w.class == M.BP_CLASS and w.title == M.BP_TITLE
end

-- The Big Picture window, or nil. "Up" means the window EXISTS, not that it
-- has focus, so a game launched from Big Picture keeps its session after BP
-- loses focus.
function M.bp_window()
    for _, w in ipairs(hl.get_windows()) do
        if M.is_bp(w) then return w end
    end
    return nil
end

function M.sh_quote(s)
    return "'" .. (tostring(s):gsub("'", "'\\''")) .. "'"
end

-- A logger for one syslog tag. The "--" matters: logger parses an argument
-- that begins with a dash as an option and rejects the whole line, so every
-- "-> STATE" transition message was silently dropped until 2026-10-19.
function M.logger(tag)
    return function(msg)
        pcall(hl.exec_cmd, "logger -t " .. tag .. " -- " .. M.sh_quote(msg))
    end
end

-- Run fn once after ms, with errors logged instead of thrown into the
-- compositor's timer loop.
function M.later(ms, fn, log)
    hl.timer(function()
        local ok, err = pcall(fn)
        if not ok and log then log("error: " .. tostring(err)) end
    end, { timeout = ms, type = "oneshot" })
end

-- The one way Steam is launched from the desktop (autostart, guide button,
-- crash recovery). Flags live in the script, not in every caller.
M.STEAM_LAUNCH = os.getenv("HOME") .. "/.local/bin/steam-launch"

-- Mirrors bp-focus.lua's BP_FOCUS_HOOKED guard: if a reload does not wipe
-- Lua globals, the load guard above would keep serving this table forever
-- and an edit to this file would never take effect.
hl.on("config.unload", function() BP_COMMON = nil end)

BP_COMMON = M
return M

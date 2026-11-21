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

function M.bp_window()
    for _, w in ipairs(hl.get_windows()) do
        if M.is_bp(w) then return w end
    end
    return nil
end

function M.sh_quote(s)
    return "'" .. (tostring(s):gsub("'", "'\\''")) .. "'"
end

function M.logger(tag)
    return function(msg)
        pcall(hl.exec_cmd, "logger -t " .. tag .. " -- " .. M.sh_quote(msg))
    end
end

function M.later(ms, fn, log)
    hl.timer(function()
        local ok, err = pcall(fn)
        if not ok and log then log("error: " .. tostring(err)) end
    end, { timeout = ms, type = "oneshot" })
end

M.STEAM_LAUNCH = os.getenv("HOME") .. "/.local/bin/steam-launch"

hl.on("config.unload", function() BP_COMMON = nil end)

BP_COMMON = M
return M

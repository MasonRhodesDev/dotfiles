-- Dumb renderer for the terminal-header daemon (~/scripts/terminal-header/).
-- All header policy — sections, ordering, agent detection, summaries — lives
-- in the daemon, which writes $XDG_RUNTIME_DIR/terminal-header/pane-<id>.json
-- as { header = string|null, updatedAtMs }. This module only reads that file.
-- The old in-process headerModules/*.lua are inert and no longer loaded.
--
-- The M.* API is kept so wezterm.lua does not change.

local wezterm = require 'wezterm'
local M = {}

local TTL_MS = 60 * 1000

local function state_root()
  local runtime = os.getenv("XDG_RUNTIME_DIR")
  if runtime and runtime ~= "" then
    return runtime .. "/terminal-header"
  end
  return (os.getenv("HOME") or ".") .. "/.cache/terminal-header"
end

local function read_header(pane)
  local ok, id = pcall(function() return pane:pane_id() end)
  if not ok or id == nil then return nil end

  local f = io.open(state_root() .. "/pane-" .. tostring(id) .. ".json", "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()

  local parsed_ok, state = pcall(wezterm.json_parse, content)
  if not parsed_ok or type(state) ~= "table" then return nil end
  if type(state.header) ~= "string" or state.header == "" then return nil end
  if type(state.updatedAtMs) ~= "number" then return nil end
  if (os.time() * 1000) - state.updatedAtMs > TTL_MS then return nil end
  return state.header
end

function M.load_modules()
  -- Header sections live in the daemon now; nothing to load in-process.
  return {}
end

function M.invalidate(pane)
  -- No cache: the daemon's file IS the cache.
end

function M.collect_components(modules, window, pane)
  local header = read_header(pane)
  if header then
    return { " " .. header }
  end
  return {}
end

function M.collect_status_components(modules, window, pane)
  local header = read_header(pane)
  if header then
    return { " " .. header }, nil
  end
  return {}, nil
end

return M

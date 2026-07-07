local wezterm = require 'wezterm'
local M = {}

-- Load all modules from headerModules/ directory
function M.load_modules()
  local modules_dir = wezterm.config_dir .. '/headerModules'
  local modules = {}

  -- Read all .lua files from headerModules/
  local success, files = pcall(function()
    return wezterm.read_dir(modules_dir)
  end)

  if not success then
    wezterm.log_warn("Failed to read headerModules directory: " .. tostring(files))
    return modules
  end

  for _, file in ipairs(files) do
    if file:match("%.lua$") then
      local basename = file:match("([^/]+)$") or file
      local module_name = basename:match("^(.+)%.lua$")
      local module_path = file

      local ok, module = pcall(dofile, module_path)
      if ok and module then
        modules[module_name] = {
          priority = module.priority or 999,
          detect = module.detect,
          get_component = module.get_component
        }
        wezterm.log_info("Loaded header module: " .. module_name)
      else
        wezterm.log_warn("Failed to load module " .. module_name .. ": " .. tostring(module))
      end
    end
  end

  return modules
end

local function active_modules_sorted(modules, pane)
  local active_modules = {}

  for name, module in pairs(modules) do
    if module.detect then
      local active, data = module.detect(pane)
      if active then
        table.insert(active_modules, {
          name = name,
          priority = module.priority,
          data = data,
          get_component = module.get_component
        })
      end
    end
  end

  table.sort(active_modules, function(a, b)
    return a.priority < b.priority
  end)

  return active_modules
end

-- Component cache: module detect/get_component hit files, JSON parsing, and
-- mux RPCs — all on the GUI thread. update-right-status fires every second
-- for every window, so uncached that work multiplies into visible input lag.
-- Cache per pane; user-var changes invalidate so agent updates still show
-- within a tick.
local component_cache = {}
local CACHE_TTL_SECONDS = 3

function M.invalidate(pane)
  local ok, id = pcall(function() return pane:pane_id() end)
  if ok and id ~= nil then
    component_cache[tostring(id)] = nil
  end
end

local function compute_components(modules, pane)
  local components = {}
  for _, active in ipairs(active_modules_sorted(modules, pane)) do
    if active.get_component then
      local component = active.get_component(pane, active.data)
      if component then
        table.insert(components, component)
      end
    end
  end
  return components
end

-- Collect active components from all modules
function M.collect_components(modules, window, pane)
  local ok, id = pcall(function() return pane:pane_id() end)
  if not ok or id == nil then
    return compute_components(modules, pane)
  end

  local key = tostring(id)
  local cached = component_cache[key]
  if cached and os.time() - cached.at < CACHE_TTL_SECONDS then
    return cached.components
  end

  local components = compute_components(modules, pane)
  component_cache[key] = { at = os.time(), components = components }
  return components
end

function M.collect_status_components(modules, window, pane)
  local left_components = {}
  local right_component = nil

  for _, active in ipairs(active_modules_sorted(modules, pane)) do
    if active.get_component then
      local component = active.get_component(pane, active.data)
      if component then
        if active.name == "pane_summary" or active.name == "private_pane_summary" then
          right_component = component
        else
          table.insert(left_components, component)
        end
      end
    end
  end

  return left_components, right_component
end

return M

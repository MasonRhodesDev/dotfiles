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

-- Collect active components from all modules
function M.collect_components(modules, window, pane)
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

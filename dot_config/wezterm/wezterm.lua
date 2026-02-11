local wezterm = require 'wezterm'
local config = {}

-- Force config reload when theme files change
config.automatically_reload_config = true

-- Improve Wayland stability during TTY switching
config.enable_wayland = true
config.front_end = "OpenGL"
config.exit_behavior = "CloseOnCleanExit"
config.skip_close_confirmation_for_processes_named = {}

-- Minimal status bar: hide tabs but keep status area for SSH indicator
config.hide_tab_bar_if_only_one_tab = false
config.show_tabs_in_tab_bar = false
config.show_new_tab_button_in_tab_bar = false

-- Dynamic opacity based on running process
config.window_background_opacity = 0.95

-- Load wezterm-config.nvim plugin (optional, guarded to avoid hard failure)
local wezterm_config_nvim = nil
if wezterm.plugin and wezterm.plugin.require then
  local ok, plugin_or_err = pcall(function()
    return wezterm.plugin.require "https://github.com/winter-again/wezterm-config.nvim"
  end)
  if ok then
    wezterm_config_nvim = plugin_or_err
  else
    wezterm.log_info("wezterm-config.nvim not available: " .. tostring(plugin_or_err))
  end
else
  wezterm.log_info("wezterm.plugin API unavailable; skipping plugins")
end

-- Load header module system
local header_loader = require('headerModulesLoader')
local header_modules = header_loader.load_modules()

-- Main status bar update handler
wezterm.on("update-right-status", function(window, pane)
  local components = header_loader.collect_components(header_modules, window, pane)

  -- Build status display
  local overrides = window:get_config_overrides() or {}

  if #components > 0 then
    -- Show tab bar and status when any indicator is active
    overrides.enable_tab_bar = true
    window:set_left_status(wezterm.format({
      { Text = table.concat(components, " | ") }
    }))
  else
    -- Hide tab bar when no indicators are active
    overrides.enable_tab_bar = false
    window:set_left_status("")
  end

  window:set_config_overrides(overrides)
end)

-- Handle user variable changes from nvim for config overrides
wezterm.on('user-var-changed', function(window, pane, name, value)
  -- Handle nvim config overrides
  if wezterm_config_nvim and wezterm_config_nvim.override_user_var then
    local overrides = window:get_config_overrides() or {}
    overrides = wezterm_config_nvim.override_user_var(overrides, name, value)
    window:set_config_overrides(overrides)
  end

  -- Handle Claude activity updates - force status bar refresh
  if name == "CLAUDE_ACTIVE" or name == "CLAUDE_ACTIVITY" or name == "CLAUDE_MODEL" then
    -- Trigger a status update by emitting update-right-status
    window:perform_action(wezterm.action.EmitEvent("update-right-status"), pane)
  end
end)

-- Load dynamic colors from lmtt (Linux Matugen Theme Toggle)
local colors_file = wezterm.config_dir .. '/lmtt-colors.lua'

-- Add the colors file to the watch list for automatic reloading
wezterm.add_to_config_reload_watch_list(colors_file)

-- Load the colors
local has_colors, colors_module = pcall(dofile, colors_file)
if has_colors and colors_module then
  config.colors = colors_module
else
  -- Fallback colors if theme switcher hasn't generated colors yet
  config.colors = {
    foreground = '#e2e2e9',
    background = '#111318',
    cursor_bg = '#aac7ff',
    cursor_fg = '#09305f',
    cursor_border = '#aac7ff',
    selection_fg = '#d6e3ff',
    selection_bg = '#274777',
    ansi = {
      '#111318', '#ffb4ab', '#a5d6a7', '#fff59d',
      '#aac7ff', '#c4c6d0', '#563e5c', '#e2e2e9',
    },
    brights = {
      '#1d2024', '#ffb4ab', '#c8e6c9', '#ffecb3',
      '#aac7ff', '#c4c6d0', '#563e5c', '#e2e2e9',
    },
  }
end

-- Font configuration
config.font = wezterm.font_with_fallback({
  'Lilex',
  'JetBrainsMono Nerd Font',
  'FiraCode Nerd Font',
})

-- Use default hyperlink rules and add file path detection
config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- Add rules for file paths with line numbers
table.insert(config.hyperlink_rules, {
  regex = [[([\w\.\-_/]+):(\d+):?(\d+)?]],
  format = 'file://$1:$2',
  highlight = 1,
})

-- Add rules for simple file paths
table.insert(config.hyperlink_rules, {
  regex = [[\b([\w\.\-_/]*[\w\.\-_]+\.(js|ts|jsx|tsx|py|rs|go|java|cpp|c|h|vue|svelte|html|css|scss|sass|less|json|yaml|yml|toml|md|txt))\b]],
  format = 'file://$1',
  highlight = 1,
})

-- Key bindings for copy/paste with system clipboard
config.keys = {
  -- Shift+Enter sends Escape+CR
  {key="Enter", mods="SHIFT", action=wezterm.action{SendString="\x1b\r"}},
  -- Copy to system clipboard
  {
    key = 'c',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.CopyTo 'Clipboard',
  },
  -- Paste from system clipboard (text)
  {
    key = 'v',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.PasteFrom 'Clipboard',
  },
  -- Smart paste: image paths for images, text for text (for Claude Code)
  {
    key = 'v',
    mods = 'CTRL',
    action = wezterm.action_callback(function(window, pane)
      local success, stdout, stderr = wezterm.run_child_process({'/home/mason/scripts/wezterm-paste-image'})
      if success and stdout and stdout ~= "" then
        pane:send_text(stdout)
      end
    end),
  },
  -- Disable Super+N to let Hyprland handle it for swaync
  {
    key = 'n',
    mods = 'SUPER',
    action = wezterm.action.DisableDefaultAssignment,
  },
}

-- Mouse bindings for link handling  
config.mouse_bindings = {
  -- Double-click to select word and open if it's a file path
  {
    event = { Up = { streak = 2, button = 'Left' } },
    mods = 'NONE',
    action = wezterm.action_callback(function(window, pane)
      -- Get the selected text (which should be the word we double-clicked)
      local selection = window:get_selection_text_for_pane(pane)
      
      -- Debug: write to file
      local debug_file = io.open('/tmp/wezterm-debug.log', 'a')
      if debug_file then
        debug_file:write('Double-click detected\n')
        debug_file:write('Selection: ' .. tostring(selection) .. '\n')
        debug_file:close()
      end
      
      if selection and selection:match('%%%.%%w+:%%d+') then
        local cwd = pane:get_current_working_dir()
        if cwd then
          cwd = cwd.file_path
        end
        
        -- Parse file:line:column format
        local file, line, column = selection:match('^(.+):(%%d+):(%%d+)$')
        if not file then
          file, line = selection:match('^(.+):(%%d+)$')
        end
        if not file then
          file = selection
        end
        
        -- Make absolute path if relative
        if not file:match('^/') and cwd then
          -- Remove trailing slash from cwd if present
          cwd = cwd:gsub('/$', '')
          file = cwd .. '/' .. file
        end
        
        local visual = os.getenv('VISUAL') or os.getenv('EDITOR') or 'vim'
        local cmd
        if line and column then
          cmd = string.format('%%s "%%s:%%s:%%s"', visual, file, line, column)
        elseif line then
          cmd = string.format('%%s "%%s:%%s"', visual, file, line)
        else
          cmd = string.format('%%s "%%s"', visual, file)
        end
        
        -- Debug: log command
        local debug_file2 = io.open('/tmp/wezterm-debug.log', 'a')
        if debug_file2 then
          debug_file2:write('Command: ' .. cmd .. '\n')
          debug_file2:write('---\n')
          debug_file2:close()
        end
        
        os.execute(cmd .. ' &')
      end
    end),
  },
  -- Regular click for other hyperlinks
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CTRL',
    action = wezterm.action.OpenLinkAtMouseCursor,
  },
}

return config

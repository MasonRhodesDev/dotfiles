local wezterm = require 'wezterm'
local config = {}

config.automatically_reload_config = false

config.default_prog = { '/usr/bin/bash', '--login' }

config.enable_wayland = true
config.front_end = "OpenGL"
config.exit_behavior = "CloseOnCleanExit"
config.notification_handling = "NeverShow"
config.skip_close_confirmation_for_processes_named = {}

config.enable_tab_bar = false
config.hide_tab_bar_if_only_one_tab = false
config.show_tabs_in_tab_bar = false
config.show_new_tab_button_in_tab_bar = false

config.window_background_opacity = 0.95

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

config.status_update_interval = 1000

local header_loader = require('headerModulesLoader')
local header_modules = header_loader.load_modules()

local header_fg = '#e2e2e9'
local header_bg = '#1d2024'

wezterm.on("update-right-status", function(window, pane)
  local components = header_loader.collect_components(header_modules, window, pane)

  if #components > 0 then
    window:set_left_status(wezterm.format({
      { Background = { Color = header_bg } },
      { Foreground = { Color = header_fg } },
      { Text = table.concat(components, " | ") }
    }))
  else
    window:set_left_status("")
  end

  window:set_right_status("")

  local want_tab_bar = #components > 0
  local overrides = window:get_config_overrides() or {}
  if (overrides.enable_tab_bar or false) ~= want_tab_bar then
    overrides.enable_tab_bar = want_tab_bar
    window:set_config_overrides(overrides)
  end
end)

wezterm.on('user-var-changed', function(window, pane, name, value)
  if name:match("^AGENT_") or name:match("^CLAUDE_") then
    return
  end

  if wezterm_config_nvim and wezterm_config_nvim.override_user_var then
    local ok, overrides = pcall(
      wezterm_config_nvim.override_user_var,
      window:get_config_overrides() or {},
      name,
      value
    )
    if ok and overrides then
      window:set_config_overrides(overrides)
    end
  end
end)

local colors_file = wezterm.config_dir .. '/lmtt-colors.lua'

wezterm.add_to_config_reload_watch_list(colors_file)

local has_colors, colors_module = pcall(dofile, colors_file)
if has_colors and colors_module then
  config.colors = colors_module

  local tab_bar = colors_module.tab_bar
  if tab_bar and tab_bar.background then
    header_bg = tab_bar.background
    header_fg = (tab_bar.inactive_tab_hover and tab_bar.inactive_tab_hover.fg_color)
        or colors_module.foreground
        or header_fg
    config.window_frame = {
      active_titlebar_bg = tab_bar.background,
      inactive_titlebar_bg = tab_bar.background,
    }
  end
else
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

config.font = wezterm.font_with_fallback({
  'Lilex',
  'JetBrainsMono Nerd Font',
  'FiraCode Nerd Font',
})

config.hyperlink_rules = wezterm.default_hyperlink_rules()

table.insert(config.hyperlink_rules, {
  regex = [[([\w\.\-_/]+):(\d+):?(\d+)?]],
  format = 'file://$1:$2',
  highlight = 1,
})

table.insert(config.hyperlink_rules, {
  regex = [[\b([\w\.\-_/]*[\w\.\-_]+\.(js|ts|jsx|tsx|py|rs|go|java|cpp|c|h|vue|svelte|html|css|scss|sass|less|json|yaml|yml|toml|md|txt))\b]],
  format = 'file://$1',
  highlight = 1,
})

config.keys = {
  {key="Enter", mods="SHIFT", action=wezterm.action{SendString="\x1b\r"}},
  {
    key = 'c',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.CopyTo 'Clipboard',
  },
  {
    key = 'v',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.PasteFrom 'Clipboard',
  },
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
  {
    key = 'n',
    mods = 'SUPER',
    action = wezterm.action.DisableDefaultAssignment,
  },
}

config.mouse_bindings = {
  {
    event = { Up = { streak = 2, button = 'Left' } },
    mods = 'NONE',
    action = wezterm.action_callback(function(window, pane)
      local selection = window:get_selection_text_for_pane(pane)
      
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
        
        local file, line, column = selection:match('^(.+):(%%d+):(%%d+)$')
        if not file then
          file, line = selection:match('^(.+):(%%d+)$')
        end
        if not file then
          file = selection
        end
        
        if not file:match('^/') and cwd then
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
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CTRL',
    action = wezterm.action.OpenLinkAtMouseCursor,
  },
}

return config

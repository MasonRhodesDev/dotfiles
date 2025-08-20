local wezterm = require 'wezterm'
local config = {}

-- Hide tab bar when only one tab is open
config.hide_tab_bar_if_only_one_tab = true

-- Set window opacity
config.window_background_opacity = 0.95
local padding = {
    left = '1cell',
    right = '1cell',
    top = '0.5cell',
    bottom = '0.5cell',
}

wezterm.on('update-status', function(window, pane)
    local overrides = window:get_config_overrides() or {}
    if string.find(pane:get_title(), '^n-vi-m-.*') then
        overrides.window_padding = {
            left = 0,
            right = 0,
            top = 0,
            bottom = 0,
        }
    else
        overrides.window_padding = padding
    end
    window:set_config_overrides(overrides)
end)

-- Material You colors generated from wallpaper
config.colors = {
  foreground = '#e2e2e9',
  background = '#111318',
  cursor_bg = '#aac7ff',
  cursor_fg = '#09305f',
  cursor_border = '#aac7ff',
  selection_fg = '#d6e3ff',
  selection_bg = '#274777',

  ansi = {
    '#111318',
    '#ffb4ab',
    '#a5d6a7',
    '#fff59d',
    '#aac7ff',
    '#c4c6d0',
    '#563e5c',
    '#e2e2e9',
  },

  brights = {
    '#1d2024',
    '#ffb4ab',
    '#c8e6c9',
    '#ffecb3',
    '#aac7ff',
    '#c4c6d0',
    '#563e5c',
    '#e2e2e9',
  },
}

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
  -- Copy to system clipboard
  {
    key = 'c',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.CopyTo 'Clipboard',
  },
  -- Paste from system clipboard
  {
    key = 'v',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.PasteFrom 'Clipboard',
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

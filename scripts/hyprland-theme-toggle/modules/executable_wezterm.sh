#!/bin/bash

# WezTerm theme module

source "$(dirname "${BASH_SOURCE[0]}")/base.sh"

wezterm_apply_theme() {
    local wallpaper="$1"
    local mode="$2"
    local state_file="$3"
    local colors_json="$4"
    
    local config_file="$HOME/.wezterm.lua"
    local module_name="WezTerm"
    
    # Check if WezTerm is installed
    if ! app_installed "wezterm"; then
        log_module "$module_name" "Not installed, skipping"
        return 0
    fi
    
    # Check if theme is already cached
    if theme_cached "$config_file" "$wallpaper" "$state_file"; then
        log_module "$module_name" "Theme cached, skipping regeneration"
        return 0
    fi
    
    log_module "$module_name" "Generating $mode theme"
    
    # Generate WezTerm config using Python with passed colors JSON
    python3 -c "
import json, sys

try:
    data = json.loads('$colors_json')
    colors = data.get('colors', {}).get('$mode', {})
    mode = '$mode'
    
    if mode == 'light':
        main_colors = {
            'foreground': colors.get('on_surface', '#1d1b20'),
            'background': colors.get('surface', '#fef7ff'),
            'cursor_bg': colors.get('primary', '#6750a4'),
            'cursor_fg': colors.get('on_primary', '#ffffff'),
            'cursor_border': colors.get('primary', '#6750a4'),
            'selection_fg': colors.get('on_primary_container', '#21005d'),
            'selection_bg': colors.get('primary_container', '#eaddff'),
        }
        ansi_colors = [
            colors.get('outline', '#79747e'),
            colors.get('error', '#ba1a1a'),
            '#2e7d32',  # green
            '#f57c00',  # yellow
            colors.get('primary', '#6750a4'),
            colors.get('on_surface_variant', '#625b71'),
            '#7d5260',  # cyan
            colors.get('on_surface', '#1d1b20')
        ]
        bright_colors = [
            colors.get('surface_container_high', '#e7e0ec'),
            colors.get('error', '#ba1a1a'),
            '#388e3c',  # bright green
            '#ff9800',  # bright yellow
            colors.get('primary', '#6750a4'),
            colors.get('on_surface_variant', '#625b71'),
            '#7d5260',  # bright cyan
            colors.get('on_surface', '#1d1b20')
        ]
    else:  # dark mode
        main_colors = {
            'foreground': colors.get('on_surface', '#e2e2e9'),
            'background': colors.get('surface', '#111318'),
            'cursor_bg': colors.get('primary', '#aac7ff'),
            'cursor_fg': colors.get('on_primary', '#09305f'),
            'cursor_border': colors.get('primary', '#aac7ff'),
            'selection_fg': colors.get('on_primary_container', '#d6e3ff'),
            'selection_bg': colors.get('primary_container', '#274777'),
        }
        ansi_colors = [
            colors.get('surface', '#111318'),
            colors.get('error', '#ffb4ab'),
            '#a5d6a7',  # green
            '#fff59d',  # yellow
            colors.get('primary', '#aac7ff'),
            colors.get('on_surface_variant', '#3e4759'),
            '#563e5c',  # cyan
            colors.get('on_surface', '#e2e2e9')
        ]
        bright_colors = [
            colors.get('surface_container', '#44474e'),
            colors.get('error', '#ffb4ab'),
            '#c8e6c9',  # bright green
            '#ffecb3',  # bright yellow
            colors.get('primary', '#aac7ff'),
            colors.get('on_surface_variant', '#3e4759'),
            '#563e5c',  # bright cyan
            colors.get('on_surface', '#e2e2e9')
        ]
    
    # Generate WezTerm Lua config
    config = f'''local wezterm = require 'wezterm'
local config = {{}}

-- Hide tab bar when only one tab is open
config.hide_tab_bar_if_only_one_tab = true

-- Set window opacity
config.window_background_opacity = 0.95

-- Material You colors generated from wallpaper
config.colors = {{
  foreground = '{main_colors['foreground']}',
  background = '{main_colors['background']}',
  cursor_bg = '{main_colors['cursor_bg']}',
  cursor_fg = '{main_colors['cursor_fg']}',
  cursor_border = '{main_colors['cursor_border']}',
  selection_fg = '{main_colors['selection_fg']}',
  selection_bg = '{main_colors['selection_bg']}',

  ansi = {{
''' + ',\\n'.join([f'    \\'{color}\\'' for color in ansi_colors]) + f''',
  }},

  brights = {{
''' + ',\\n'.join([f'    \\'{color}\\'' for color in bright_colors]) + f''',
  }},
}}

-- Use default hyperlink rules and add file path detection
config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- Add rules for file paths with line numbers
table.insert(config.hyperlink_rules, {{
  regex = [[([\\\\w\\\\.\\\\-_/]+):(\\\\d+):?(\\\\d+)?]],
  format = 'file://\$1:\$2',
  highlight = 1,
}})

-- Add rules for simple file paths
table.insert(config.hyperlink_rules, {{
  regex = [[\\\\b([\\\\w\\\\.\\\\-_/]*[\\\\w\\\\.\\\\-_]+\\\\.(js|ts|jsx|tsx|py|rs|go|java|cpp|c|h|vue|svelte|html|css|scss|sass|less|json|yaml|yml|toml|md|txt))\\\\b]],
  format = 'file://\$1',
  highlight = 1,
}})

-- Key bindings for copy/paste with system clipboard
config.keys = {{
  -- Copy to system clipboard
  {{
    key = 'c',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.CopyTo 'Clipboard',
  }},
  -- Paste from system clipboard
  {{
    key = 'v',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.PasteFrom 'Clipboard',
  }},
}}

-- Mouse bindings for link handling  
config.mouse_bindings = {{
  -- Double-click to select word and open if it's a file path
  {{
    event = {{ Up = {{ streak = 2, button = 'Left' }} }},
    mods = 'NONE',
    action = wezterm.action_callback(function(window, pane)
      -- Get the selected text (which should be the word we double-clicked)
      local selection = window:get_selection_text_for_pane(pane)
      
      -- Debug: write to file
      local debug_file = io.open('/tmp/wezterm-debug.log', 'a')
      if debug_file then
        debug_file:write('Double-click detected\\\\n')
        debug_file:write('Selection: ' .. tostring(selection) .. '\\\\n')
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
          cmd = string.format('%%s \"%%s:%%s:%%s\"', visual, file, line, column)
        elseif line then
          cmd = string.format('%%s \"%%s:%%s\"', visual, file, line)
        else
          cmd = string.format('%%s \"%%s\"', visual, file)
        end
        
        -- Debug: log command
        local debug_file2 = io.open('/tmp/wezterm-debug.log', 'a')
        if debug_file2 then
          debug_file2:write('Command: ' .. cmd .. '\\\\n')
          debug_file2:write('---\\\\n')
          debug_file2:close()
        end
        
        os.execute(cmd .. ' &')
      end
    end),
  }},
  -- Regular click for other hyperlinks
  {{
    event = {{ Up = {{ streak = 1, button = 'Left' }} }},
    mods = 'CTRL',
    action = wezterm.action.OpenLinkAtMouseCursor,
  }},
}}

return config'''
    
    with open('$config_file', 'w') as f:
        f.write(config)
    
    print('Generated WezTerm config: $config_file')
    
except Exception as e:
    print(f'Error generating WezTerm config: {e}')
    sys.exit(1)
"
    
    return $?
}
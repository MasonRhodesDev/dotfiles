#!/usr/bin/env python3

import json
import sys
import os
import subprocess

def generate_wofi_css(colors):
    """Generate Wofi CSS from Material You colors"""
    css_template = """window {{
    margin: 0px;
    border: 1px solid {primary};
    background-color: {surface};
    }}
    
    #input {{
    margin: 5px;
    border: none;
    color: {on_surface};
    background-color: {surface_variant};
    }}
    
    #inner-box {{
    margin: 5px;
    border: none;
    background-color: {surface};
    }}
    
    #outer-box {{
    margin: 5px;
    border: none;
    background-color: {surface};
    }}
    
    #scroll {{
    margin: 0px;
    border: none;
    }}
    
    #text {{
    margin: 5px;
    border: none;
    color: {on_surface};
    }} 
    
    #entry.activatable #text {{
    color: {on_primary};
    }}
    
    #entry > * {{
    color: {on_surface};
    }}
    
    #entry:selected {{
    background-color: {primary_container};
    }}
    
    #entry:selected #text {{
    font-weight: bold;
    color: {on_primary_container};
    }}"""
    
    return css_template.format(
        primary=colors.get('primary', '#6750a4'),
        surface=colors.get('surface', '#fef7ff'),
        on_surface=colors.get('on_surface', '#1d1b20'),
        surface_variant=colors.get('surface_variant', '#e7e0ec'),
        on_primary=colors.get('on_primary', '#ffffff'),
        primary_container=colors.get('primary_container', '#eaddff'),
        on_primary_container=colors.get('on_primary_container', '#21005d')
    )

def generate_wezterm_config(colors, mode):
    """Generate WezTerm config from Material You colors"""
    
    # Adjust colors based on light/dark mode for better readability
    if mode == 'light':
        # Light mode: use darker colors for text, lighter for background
        ansi_colors = [
            colors.get('outline', '#79747e'),  # black - use outline for better contrast
            colors.get('error', '#ba1a1a'),    # red
            '#2e7d32',                         # green - manually set for readability
            '#f57c00',                         # yellow - manually set for readability  
            colors.get('primary', '#6750a4'),  # blue
            colors.get('secondary', '#625b71'), # magenta
            colors.get('tertiary', '#7d5260'),  # cyan
            colors.get('on_surface', '#1d1b20'), # white
        ]
        bright_colors = [
            colors.get('surface_variant', '#e7e0ec'), # bright black
            colors.get('error', '#ba1a1a'),    # bright red
            '#388e3c',                         # bright green
            '#ff9800',                         # bright yellow
            colors.get('primary', '#6750a4'),  # bright blue
            colors.get('secondary', '#625b71'), # bright magenta
            colors.get('tertiary', '#7d5260'),  # bright cyan
            colors.get('on_surface', '#1d1b20'), # bright white
        ]
    else:
        # Dark mode: use lighter colors for text, darker for background
        ansi_colors = [
            colors.get('surface', '#111318'),   # black
            colors.get('error', '#ffb4ab'),     # red
            '#a5d6a7',                         # green - manually set for readability
            '#fff59d',                         # yellow - manually set for readability
            colors.get('primary', '#aac7ff'),  # blue
            colors.get('secondary_container', '#3e4759'), # magenta
            colors.get('tertiary_container', '#563e5c'),  # cyan
            colors.get('on_surface', '#e2e2e9'), # white
        ]
        bright_colors = [
            colors.get('surface_variant', '#44474e'), # bright black
            colors.get('error', '#ffb4ab'),     # bright red
            '#c8e6c9',                         # bright green
            '#ffecb3',                         # bright yellow
            colors.get('primary', '#aac7ff'),  # bright blue
            colors.get('secondary_container', '#3e4759'), # bright magenta
            colors.get('tertiary_container', '#563e5c'),  # bright cyan
            colors.get('on_surface', '#e2e2e9'), # bright white
        ]
    
    ansi_str = ',\n    '.join([f"'{color}'" for color in ansi_colors])
    brights_str = ',\n    '.join([f"'{color}'" for color in bright_colors])
    
    lua_template = """local wezterm = require 'wezterm'
local config = {{}}

-- Hide tab bar when only one tab is open
config.hide_tab_bar_if_only_one_tab = true

-- Set window opacity
config.window_background_opacity = 0.95

-- Material You colors generated from wallpaper
config.colors = {{
  foreground = '{on_surface}',
  background = '{surface}',
  cursor_bg = '{primary}',
  cursor_fg = '{on_primary}',
  cursor_border = '{primary}',
  selection_fg = '{on_primary_container}',
  selection_bg = '{primary_container}',

  ansi = {{
    {ansi_colors}
  }},

  brights = {{
    {bright_colors}
  }},
}}

-- Use default hyperlink rules and add file path detection
config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- Add rules for file paths with line numbers
table.insert(config.hyperlink_rules, {{
  regex = [[([{backslash}w{backslash}.{backslash}-_/]+):({backslash}d+):?({backslash}d+)?]],
  format = 'file://$1:$2',
  highlight = 1,
}})

-- Add rules for simple file paths
table.insert(config.hyperlink_rules, {{
  regex = [[{backslash}b([{backslash}w{backslash}.{backslash}-_/]*[{backslash}w{backslash}.{backslash}-_]+{backslash}.(js|ts|jsx|tsx|py|rs|go|java|cpp|c|h|vue|svelte|html|css|scss|sass|less|json|yaml|yml|toml|md|txt)){backslash}b]],
  format = 'file://$1',
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
        debug_file:write('Double-click detected\\n')
        debug_file:write('Selection: ' .. tostring(selection) .. '\\n')
        debug_file:close()
      end
      
      if selection and selection:match('%.%w+:%d+') then
        local cwd = pane:get_current_working_dir()
        if cwd then
          cwd = cwd.file_path
        end
        
        -- Parse file:line:column format
        local file, line, column = selection:match('^(.+):(%d+):(%d+)$')
        if not file then
          file, line = selection:match('^(.+):(%d+)$')
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
          cmd = string.format('%s "%s:%s:%s"', visual, file, line, column)
        elseif line then
          cmd = string.format('%s "%s:%s"', visual, file, line)
        else
          cmd = string.format('%s "%s"', visual, file)
        end
        
        -- Debug: log command
        local debug_file2 = io.open('/tmp/wezterm-debug.log', 'a')
        if debug_file2 then
          debug_file2:write('Command: ' .. cmd .. '\\n')
          debug_file2:write('---\\n')
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

return config"""
    
    # Set main colors based on mode
    if mode == 'light':
        main_colors = {
            'foreground': colors.get('on_surface', '#1d1b20'),
            'background': colors.get('surface', '#fef7ff'),  
            'primary': colors.get('primary', '#6750a4'),
            'on_primary': colors.get('on_primary', '#ffffff'),
            'on_primary_container': colors.get('on_primary_container', '#21005d'),
            'primary_container': colors.get('primary_container', '#eaddff'),
        }
    else:  # dark mode
        main_colors = {
            'foreground': colors.get('on_surface', '#e2e2e9'),
            'background': colors.get('surface', '#111318'),
            'primary': colors.get('primary', '#aac7ff'),
            'on_primary': colors.get('on_primary', '#09305f'),
            'on_primary_container': colors.get('on_primary_container', '#d6e3ff'),
            'primary_container': colors.get('primary_container', '#274777'),
        }
    
    return lua_template.format(
        on_surface=main_colors['foreground'],
        surface=main_colors['background'],
        primary=main_colors['primary'],
        on_primary=main_colors['on_primary'],
        on_primary_container=main_colors['on_primary_container'],
        primary_container=main_colors['primary_container'],
        ansi_colors=ansi_str,
        bright_colors=brights_str,
        backslash='\\'
    )

def main():
    if len(sys.argv) != 3:
        print("Usage: generate-theme-configs.py <wallpaper_path> <mode>")
        sys.exit(1)
    
    wallpaper_path = sys.argv[1]
    mode = sys.argv[2]
    
    # Get colors from matugen
    try:
        result = subprocess.run([
            'matugen', 'image', wallpaper_path, '-m', mode, '--json', 'hex'
        ], capture_output=True, text=True, check=True)
        
        colors = json.loads(result.stdout)
        
        # Generate Wofi CSS
        wofi_css = generate_wofi_css(colors)
        wofi_path = os.path.expanduser('~/.config/wofi/style.css')
        with open(wofi_path, 'w') as f:
            f.write(wofi_css)
        print(f"Generated Wofi CSS: {wofi_path}")
        
        # Generate WezTerm config
        wezterm_config = generate_wezterm_config(colors, mode)
        wezterm_path = os.path.expanduser('~/.wezterm.lua')
        with open(wezterm_path, 'w') as f:
            f.write(wezterm_config)
        print(f"Generated WezTerm config: {wezterm_path}")
        
    except subprocess.CalledProcessError as e:
        print(f"Error running matugen: {e}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error parsing matugen output: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
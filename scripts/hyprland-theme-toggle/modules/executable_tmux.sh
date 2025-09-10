#!/bin/bash

# Tmux theme module

source "$(dirname "${BASH_SOURCE[0]}")/base.sh"

tmux_apply_theme() {
    local wallpaper="$1"
    local mode="$2"
    local state_file="$3"
    local colors_json="$4"
    
    local theme_file="$HOME/.config/tmux/tmux-theme.conf"
    local module_name="Tmux"
    
    # Check if tmux is installed
    if ! app_installed "tmux"; then
        log_module "$module_name" "Not installed, skipping"
        return 0
    fi
    
    # Create tmux config directory if it doesn't exist
    mkdir -p "$(dirname "$theme_file")"
    
    log_module "$module_name" "Generating $mode theme"
    
    # Generate tmux theme file using Python with passed colors JSON
    python3 -c "
import json, sys

try:
    data = json.loads('$colors_json')
    colors = data.get('colors', {}).get('$mode', {})
    mode = '$mode'
    
    if mode == 'light':
        theme_colors = {
            'bg': colors.get('surface', '#fef7ff'),
            'fg': colors.get('on_surface', '#1d1b20'),
            'accent': colors.get('primary', '#6750a4'),
            'accent_fg': colors.get('on_primary', '#ffffff'),
            'surface_variant': colors.get('surface_container_high', '#e7e0ec'),
            'on_surface_variant': colors.get('on_surface_variant', '#44474e'),
            'outline': colors.get('outline', '#79747e'),
            'command_mode_bg': '#ff4500',  # Bright orange-red for command mode
            'command_mode_fg': '#ffffff',  # White text on orange
            'normal_mode_bg': '#228b22',   # Green for normal mode
            'normal_mode_fg': '#ffffff'    # White text on green
        }
    else:  # dark mode
        theme_colors = {
            'bg': colors.get('surface', '#111318'),
            'fg': colors.get('on_surface', '#e2e2e9'),
            'accent': colors.get('primary', '#aac7ff'),
            'accent_fg': colors.get('on_primary', '#09305f'),
            'surface_variant': colors.get('surface_container', '#1d2024'),
            'on_surface_variant': colors.get('on_surface_variant', '#c4c6d0'),
            'outline': colors.get('outline', '#8e9099'),
            'command_mode_bg': '#ff4500',  # Bright orange-red for command mode
            'command_mode_fg': '#ffffff',  # White text on orange
            'normal_mode_bg': '#32cd32',   # Brighter green for dark mode
            'normal_mode_fg': '#000000'    # Black text on green
        }
    
    # Convert hex colors to tmux color format (remove #)
    for key, value in theme_colors.items():
        if value.startswith('#'):
            theme_colors[key] = value[1:]  # Remove # for tmux
    
    # Define the tmux theme content
    theme_content = f'''# Generated Material You theme for tmux
# Theme mode: {mode}

# Normal mode: Green status bar background
set -g status-style \"bg=#{theme_colors['normal_mode_bg']},fg=#{theme_colors['normal_mode_fg']}\"
set -g status-left-style \"bg=#{theme_colors['normal_mode_bg']},fg=#{theme_colors['normal_mode_fg']}\"
set -g status-right-style \"bg=#{theme_colors['normal_mode_bg']},fg=#{theme_colors['normal_mode_fg']}\"

# Window status styling with green background
set -g window-status-style \"bg=#{theme_colors['normal_mode_bg']},fg=#{theme_colors['normal_mode_fg']}\"
set -g window-status-current-style \"bg=#{theme_colors['accent']},fg=#{theme_colors['accent_fg']}\"
set -g window-status-activity-style \"bg=#{theme_colors['outline']},fg=#{theme_colors['fg']}\"

# Status bar content with full green background
set -g status-left \"#[bg=#{theme_colors['normal_mode_bg']},fg=#{theme_colors['normal_mode_fg']},bold] Session: #S \"
set -g status-right \"#[bg=#{theme_colors['normal_mode_bg']},fg=#{theme_colors['normal_mode_fg']},bold] %H:%M %d-%b \"

# Pane border colors  
set -g pane-border-style \"fg=#{theme_colors['outline']}\"
set -g pane-active-border-style \"fg=#{theme_colors['accent']}\"

# Command mode colors (orange) - this affects the command prompt
set -g message-style \"bg=#{theme_colors['command_mode_bg']},fg=#{theme_colors['command_mode_fg']},bold\"
set -g message-command-style \"bg=#{theme_colors['command_mode_bg']},fg=#{theme_colors['command_mode_fg']},bold\"

# Copy mode styling
set -g mode-style \"bg=#{theme_colors['accent']},fg=#{theme_colors['accent_fg']}\"

# Clock mode color
set -g clock-mode-colour \"#{theme_colors['accent']}\"
'''
    
    # Write the theme file
    with open('$theme_file', 'w') as f:
        f.write(theme_content)
    
    print('Generated tmux theme: $theme_file')
    
    # Reload tmux config for all sessions
    import subprocess
    try:
        subprocess.run(['tmux', 'source-file', '$HOME/.tmux.conf'], check=True, capture_output=True)
        print('Reloaded tmux configuration')
    except subprocess.CalledProcessError:
        print('Note: Could not reload tmux config (no active sessions)')
    except FileNotFoundError:
        pass  # tmux not running, that's fine
    
except Exception as e:
    print(f'Error generating tmux theme: {e}')
    sys.exit(1)
"
    
    return $?
}
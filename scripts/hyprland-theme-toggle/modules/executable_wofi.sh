#!/bin/bash

# Wofi theme module

source "$(dirname "${BASH_SOURCE[0]}")/base.sh"

wofi_apply_theme() {
    local wallpaper="$1"
    local mode="$2"
    local state_file="$3"
    
    local config_file="$HOME/.config/wofi/style.css"
    local module_name="Wofi"
    
    # Check if Wofi is installed
    if ! app_installed "wofi"; then
        log_module "$module_name" "Not installed, skipping"
        return 0
    fi
    
    # Check if theme is already cached
    if theme_cached "$config_file" "$wallpaper" "$state_file"; then
        log_module "$module_name" "Theme cached, skipping regeneration"
        return 0
    fi
    
    log_module "$module_name" "Generating $mode theme"
    
    # Get matugen colors directly
    local colors_json=$(matugen --json hex --dry-run image "$wallpaper" --mode "$mode")
    if [[ $? -ne 0 ]]; then
        log_module "$module_name" "Error: Failed to get colors from matugen"
        return 1
    fi
    
    # Ensure config directory exists
    mkdir -p "$(dirname "$config_file")"
    
    # Generate Wofi CSS using Python
    python3 -c "
import json, sys

try:
    data = json.loads('$colors_json')
    colors = data.get('colors', {}).get('$mode', {})
    mode = '$mode'
    
    if mode == 'light':
        theme_colors = {
            'window_bg': colors.get('surface', '#fef7ff'),
            'window_border': colors.get('primary', '#6750a4'),
            'input_bg': colors.get('surface_container_high', '#e7e0ec'),
            'text_color': colors.get('on_surface', '#1d1b20'),
            'selection_bg': colors.get('primary_container', '#eaddff'),
            'selection_text': colors.get('on_primary_container', '#21005d'),
            'activatable_text': colors.get('on_primary', '#ffffff')
        }
    else:  # dark mode
        theme_colors = {
            'window_bg': colors.get('surface', '#111318'),
            'window_border': colors.get('primary', '#aac7ff'),
            'input_bg': colors.get('surface_container', '#44474e'),
            'text_color': colors.get('on_surface', '#e2e2e9'),
            'selection_bg': colors.get('primary_container', '#274777'),
            'selection_text': colors.get('on_primary_container', '#d6e3ff'),
            'activatable_text': colors.get('on_primary', '#09305f')
        }
    
    # Generate Wofi CSS
    css = f'''window {{
    margin: 0px;
    border: 1px solid {theme_colors['window_border']};
    background-color: {theme_colors['window_bg']};
    }}
    
    #input {{
    margin: 5px;
    border: none;
    color: {theme_colors['text_color']};
    background-color: {theme_colors['input_bg']};
    }}
    
    #inner-box {{
    margin: 5px;
    border: none;
    background-color: {theme_colors['window_bg']};
    }}
    
    #outer-box {{
    margin: 5px;
    border: none;
    background-color: {theme_colors['window_bg']};
    }}
    
    #scroll {{
    margin: 0px;
    border: none;
    }}
    
    #text {{
    margin: 5px;
    border: none;
    color: {theme_colors['text_color']};
    }} 
    
    #entry.activatable #text {{
    color: {theme_colors['activatable_text']};
    }}
    
    #entry > * {{
    color: {theme_colors['text_color']};
    }}
    
    #entry:selected {{
    background-color: {theme_colors['selection_bg']};
    }}
    
    #entry:selected #text {{
    font-weight: bold;
    color: {theme_colors['selection_text']};
    }}'''
    
    with open('$config_file', 'w') as f:
        f.write(css)
    
    print('Generated Wofi CSS: $config_file')
    
except Exception as e:
    print(f'Error generating Wofi CSS: {e}')
    sys.exit(1)
"
    
    return $?
}
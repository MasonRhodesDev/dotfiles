#!/bin/bash

# Fish shell theme module

source "$(dirname "${BASH_SOURCE[0]}")/base.sh"

fish_apply_theme() {
    local wallpaper="$1"
    local mode="$2"
    local state_file="$3"
    local colors_json="$4"

    local colors_file="$HOME/.config/fish/conf.d/theme-colors.fish"
    local module_name="Fish"

    # Check if Fish is installed
    if ! app_installed "fish"; then
        log_module "$module_name" "Not installed, skipping"
        return 0
    fi

    # Check if theme is already cached
    if theme_cached "$colors_file" "$wallpaper" "$state_file"; then
        log_module "$module_name" "Theme cached, skipping regeneration"
        return 0
    fi

    log_module "$module_name" "Generating $mode theme"

    # Generate Fish config using Python with passed colors JSON
    python3 -c "
import json, sys

try:
    data = json.loads('$colors_json')
    colors = data.get('colors', {}).get('$mode', {})

    # Generate Fish colors config
    fish_config = f'''# Fish shell colors generated from matugen
# Mode: $mode

# Basic colors
set -g fish_color_normal '{colors.get('on_surface', '#e3e1ec')}'
set -g fish_color_command '{colors.get('primary', '#9fd491')}'
set -g fish_color_param '{colors.get('on_surface', '#e3e1ec')}'
set -g fish_color_redirection '{colors.get('secondary', '#edb8cd')}'
set -g fish_color_comment '{colors.get('outline', '#8f909f')}'
set -g fish_color_error '{colors.get('error', '#ffb4ab')}'
set -g fish_color_escape '{colors.get('tertiary', '#bbc3fa')}'
set -g fish_color_operator '{colors.get('primary', '#9fd491')}'
set -g fish_color_quote '{colors.get('secondary', '#edb8cd')}'
set -g fish_color_autosuggestion '{colors.get('outline', '#8f909f')}'

# Selection colors
set -g fish_color_selection --background='{colors.get('primary_container', '#22511c')}'
set -g fish_color_search_match --background='{colors.get('tertiary_container', '#3b4472')}'

# Completion pager colors - using brighter/more visible colors
set -g fish_pager_color_completion '{colors.get('on_surface', '#e3e1ec')}'
set -g fish_pager_color_description '{colors.get('on_surface_variant', '#c5c5d6')}'
set -g fish_pager_color_prefix '{colors.get('primary', '#9fd491')}'
set -g fish_pager_color_progress '{colors.get('outline', '#8f909f')}'
set -g fish_pager_color_selected_background --background='{colors.get('surface_container_high', '#292931')}'
'''

    with open('$colors_file', 'w') as f:
        f.write(fish_config)

    print('Generated Fish colors: $colors_file')

except Exception as e:
    print(f'Error generating Fish config: {e}')
    sys.exit(1)
"

    log_module "$module_name" "Colors generated - restart fish shells to apply"

    return $?
}

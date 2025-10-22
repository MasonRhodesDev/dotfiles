#!/bin/bash

# Hyprlock theme module

source "$(dirname "${BASH_SOURCE[0]}")/base.sh"

hyprlock_apply_theme() {
    local wallpaper="$1"
    local mode="$2"
    local state_file="$3"
    
    local module_name="Hyprlock"
    local colors_file="$HOME/.config/matugen/colors.css"
    local hyprlock_config="$HOME/.config/hypr/hyprlock.conf"
    
    # Check if hyprlock config exists
    if [[ ! -f "$hyprlock_config" ]]; then
        log_module "$module_name" "Config not found, skipping"
        return 0
    fi
    
    if [[ ! -f "$colors_file" ]]; then
        log_module "$module_name" "Colors file not found, skipping"
        return 0
    fi
    
    log_module "$module_name" "Updating lock screen colors for $mode theme"
    
    # Extract colors
    local surface=$(grep "^@define-color surface " "$colors_file" | grep -o '#[0-9a-fA-F]\{6\}' | head -1)
    local on_surface=$(grep "^@define-color on_surface " "$colors_file" | grep -o '#[0-9a-fA-F]\{6\}' | head -1)
    local primary=$(grep "^@define-color primary " "$colors_file" | grep -o '#[0-9a-fA-F]\{6\}' | head -1)
    local primary_container=$(grep "^@define-color primary_container " "$colors_file" | grep -o '#[0-9a-fA-F]\{6\}' | head -1)
    local error=$(grep "^@define-color error " "$colors_file" | grep -o '#[0-9a-fA-F]\{6\}' | head -1)
    local secondary=$(grep "^@define-color secondary " "$colors_file" | grep -o '#[0-9a-fA-F]\{6\}' | head -1)
    
    # Convert hex to RGB for hyprlock format (no #)
    local rgb_surface="${surface#\#}"
    local rgb_on_surface="${on_surface#\#}"
    local rgb_primary="${primary#\#}"
    local rgb_primary_container="${primary_container#\#}"
    local rgb_error="${error#\#}"
    local rgb_secondary="${secondary#\#}"
    
    # Update background color
    sed -i "s/color = rgba(.*/color = rgba(${rgb_surface:0:2}, ${rgb_surface:2:2}, ${rgb_surface:4:2}, 1.0)/" "$hyprlock_config"
    
    # Update label (greeting) color
    sed -i "/^label {/,/^}/ s/color = rgba(.*/color = rgba(${rgb_primary:0:2}, ${rgb_primary:2:2}, ${rgb_primary:4:2}, 1.0)/" "$hyprlock_config"
    
    # Update input field colors
    sed -i "/^input-field {/,/^}/ s/outer_color = rgb(.*/outer_color = rgb($rgb_primary_container)/" "$hyprlock_config"
    sed -i "/^input-field {/,/^}/ s/inner_color = rgb(.*/inner_color = rgb($rgb_surface)/" "$hyprlock_config"
    sed -i "/^input-field {/,/^}/ s/font_color = rgb(.*/font_color = rgb($rgb_on_surface)/" "$hyprlock_config"
    sed -i "/^input-field {/,/^}/ s/check_color = rgb(.*/check_color = rgb($rgb_primary)/" "$hyprlock_config"
    sed -i "/^input-field {/,/^}/ s/fail_color = rgb(.*/fail_color = rgb($rgb_error)/" "$hyprlock_config"
    
    log_module "$module_name" "Updated lock screen with Material You colors"
    
    return 0
}

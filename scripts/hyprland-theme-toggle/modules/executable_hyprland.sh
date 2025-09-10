#!/bin/bash

# Hyprland borders theme module

source "$(dirname "${BASH_SOURCE[0]}")/base.sh"

hyprland_apply_theme() {
    local wallpaper="$1"
    local mode="$2"
    local state_file="$3"
    
    local module_name="Hyprland"
    
    # Check if Hyprland is running
    if ! pgrep -x Hyprland >/dev/null; then
        log_module "$module_name" "Not running, skipping"
        return 0
    fi
    
    log_module "$module_name" "Updating border colors for $mode theme"
    
    # Get colors from matugen generated colors.css
    local colors_file="$HOME/.config/matugen/colors.css"
    
    if [[ ! -f "$colors_file" ]]; then
        log_module "$module_name" "Colors file not found at $colors_file"
        return 1
    fi
    
    # Extract colors (remove # and @define-color prefix)
    local error_color=$(grep "@define-color error " "$colors_file" | sed 's/@define-color error #//' | sed 's/;//')
    local outline_color=$(grep "@define-color outline " "$colors_file" | sed 's/@define-color outline #//' | sed 's/;//')
    
    if [[ -z "$error_color" || -z "$outline_color" ]]; then
        log_module "$module_name" "Could not extract colors from $colors_file"
        return 1
    fi
    
    # Update Hyprland config
    local style_config="$HOME/.config/hypr/configs/style.conf"
    
    if [[ ! -f "$style_config" ]]; then
        log_module "$module_name" "Style config not found at $style_config"
        return 1
    fi
    
    # Update active border color (use error color for high contrast)
    sed -i "s/col.active_border=.*/col.active_border=rgb($error_color)/" "$style_config"
    
    # Update inactive border color
    sed -i "s/col.inactive_border=.*/col.inactive_border=rgb($outline_color)/" "$style_config"
    
    # Update group border colors
    sed -i "s/col.border_active=.*/col.border_active=rgb($error_color)/" "$style_config"
    sed -i "s/col.border_inactive=.*/col.border_inactive=rgb($outline_color)/" "$style_config"
    
    # Update groupbar colors
    sed -i "/groupbar {/,/}/ s/col.active=.*/col.active=rgb($error_color)/" "$style_config"
    sed -i "/groupbar {/,/}/ s/col.inactive=.*/col.inactive=rgb($outline_color)/" "$style_config"
    
    # Note: Hyprland will automatically pick up config changes
    log_module "$module_name" "Updated border colors (restart Hyprland to apply)"
    
    return 0
}

# Execute the function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    hyprland_apply_theme "$@"
fi
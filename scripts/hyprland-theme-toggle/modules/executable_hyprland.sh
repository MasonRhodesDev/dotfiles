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
    local primary_color=$(grep "@define-color primary " "$colors_file" | sed 's/@define-color primary #//' | sed 's/;//' | head -1)
    local secondary_color=$(grep "@define-color secondary " "$colors_file" | sed 's/@define-color secondary #//' | sed 's/;//' | head -1)
    local outline_color=$(grep "@define-color outline " "$colors_file" | sed 's/@define-color outline #//' | sed 's/;//' | head -1)
    local shadow_color=$(grep "@define-color shadow " "$colors_file" | sed 's/@define-color shadow #//' | sed 's/;//' | head -1)
    
    if [[ -z "$primary_color" || -z "$outline_color" ]]; then
        log_module "$module_name" "Could not extract colors from $colors_file"
        return 1
    fi
    
    # Update Hyprland config
    local style_config="$HOME/.config/hypr/configs/style.conf"
    
    if [[ ! -f "$style_config" ]]; then
        log_module "$module_name" "Style config not found at $style_config"
        return 1
    fi
    
    # Update active border with gradient (primary + secondary for dynamic effect)
    if [[ -n "$secondary_color" ]]; then
        sed -i "s/col.active_border=.*/col.active_border=rgb($primary_color) rgb($secondary_color) 45deg/" "$style_config"
    else
        sed -i "s/col.active_border=.*/col.active_border=rgb($primary_color)/" "$style_config"
    fi
    
    # Update inactive border color
    sed -i "s/col.inactive_border=.*/col.inactive_border=rgb($outline_color)/" "$style_config"
    
    # Update group border colors with gradient
    if [[ -n "$secondary_color" ]]; then
        sed -i "s/col.border_active=.*/col.border_active=rgb($primary_color) rgb($secondary_color) 45deg/" "$style_config"
    else
        sed -i "s/col.border_active=.*/col.border_active=rgb($primary_color)/" "$style_config"
    fi
    sed -i "s/col.border_inactive=.*/col.border_inactive=rgb($outline_color)/" "$style_config"
    
    # Update groupbar colors with gradient
    if [[ -n "$secondary_color" ]]; then
        sed -i "/groupbar {/,/}/ s/col.active=.*/col.active=rgb($primary_color) rgb($secondary_color) 45deg/" "$style_config"
    else
        sed -i "/groupbar {/,/}/ s/col.active=.*/col.active=rgb($primary_color)/" "$style_config"
    fi
    sed -i "/groupbar {/,/}/ s/col.inactive=.*/col.inactive=rgb($outline_color)/" "$style_config"
    
    # Update shadow color if specified in config
    if [[ -n "$shadow_color" ]]; then
        sed -i "s/col.shadow=.*/col.shadow=rgb($shadow_color)/" "$style_config" 2>/dev/null || true
        sed -i "s/col.shadow_inactive=.*/col.shadow_inactive=rgb($shadow_color)/" "$style_config" 2>/dev/null || true
    fi
    
    # Note: Hyprland will automatically pick up config changes
    log_module "$module_name" "Updated border colors with Material You gradient and shadows"
    
    return 0
}

# Execute the function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    hyprland_apply_theme "$@"
fi
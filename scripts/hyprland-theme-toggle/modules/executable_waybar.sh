#!/bin/bash

# Waybar theme module

source "$(dirname "${BASH_SOURCE[0]}")/base.sh"

waybar_apply_theme() {
    local wallpaper="$1"
    local mode="$2"
    local state_file="$3"
    
    local module_name="Waybar"
    
    # Check if Waybar is installed
    if ! app_installed "waybar"; then
        log_module "$module_name" "Not installed, skipping"
        return 0
    fi
    
    log_module "$module_name" "Updating theme for $mode mode"
    
    # Check if matugen template exists
    local template_file="$HOME/.config/matugen/templates/waybar.css"
    local output_file="$HOME/.config/waybar/matugen.css"
    
    if [[ -f "$template_file" ]]; then
        # Matugen will generate the CSS file from template
        log_module "$module_name" "Matugen will generate waybar CSS from template"
    else
        log_module "$module_name" "Warning: Matugen template not found at $template_file"
    fi
    
    # Signal waybar to reload configuration
    if pgrep -x waybar >/dev/null; then
        log_module "$module_name" "Reloading waybar configuration"
        pkill -SIGUSR2 waybar
    else
        log_module "$module_name" "Waybar not running, no reload needed"
    fi
    
    return 0
}
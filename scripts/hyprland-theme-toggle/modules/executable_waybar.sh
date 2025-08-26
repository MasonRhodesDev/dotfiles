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
    
    log_module "$module_name" "Using centralized colors for $mode theme"
    
    # Signal waybar to reload configuration
    if pgrep -x waybar >/dev/null; then
        log_module "$module_name" "Reloading waybar configuration"
        pkill -SIGUSR2 waybar
    else
        log_module "$module_name" "Waybar not running, no reload needed"
    fi
    
    return 0
}
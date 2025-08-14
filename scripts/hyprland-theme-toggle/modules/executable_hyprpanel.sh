#!/bin/bash

# HyprPanel theme module

source "$(dirname "${BASH_SOURCE[0]}")/base.sh"

hyprpanel_apply_theme() {
    local wallpaper="$1"
    local mode="$2"
    local state_file="$3"
    
    local module_name="HyprPanel"
    
    # Check if HyprPanel is installed
    if ! app_installed "hyprpanel"; then
        log_module "$module_name" "Not installed, skipping"
        return 0
    fi
    
    log_module "$module_name" "Restarting for $mode theme"
    
    # HyprPanel automatically picks up matugen colors, just restart it
    pkill -f hyprpanel
    sleep 2
    hyprpanel &
    
    return 0
}
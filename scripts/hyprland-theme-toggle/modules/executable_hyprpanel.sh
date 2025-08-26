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
    
    log_module "$module_name" "Updating config for $mode theme"
    
    # Update the HyprPanel config file
    local config_file="$HOME/.config/hyprpanel/config.json"
    
    if [[ -f "$config_file" ]]; then
        # Use jq to update the specific config value
        /usr/bin/jq --arg mode "$mode" '.["theme.matugen_settings.mode"] = $mode' "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
        log_module "$module_name" "Updated config: theme.matugen_settings.mode = $mode"
        
        # Restart hyprpanel to apply the theme
        if pgrep -x hyprpanel >/dev/null; then
            log_module "$module_name" "Restarting hyprpanel to apply theme changes"
            pkill hyprpanel
            sleep 0.5
            hyprpanel &
        else
            log_module "$module_name" "Starting hyprpanel with new theme"
            hyprpanel &
        fi
    fi
    
    return 0
}
#!/bin/bash

# Waybar theme module

source "$(dirname "${BASH_SOURCE[0]}")/base.sh"

waybar_apply_theme() {
    local wallpaper="$1"
    local mode="$2"
    local state_file="$3"
    local colors_json="$4"
    
    local module_name="Waybar"
    local colors_file="$HOME/.config/matugen/colors.css"
    
    # Check if Waybar is installed
    if ! app_installed "waybar"; then
        log_module "$module_name" "Not installed, skipping"
        return 0
    fi
    
    log_module "$module_name" "Generating centralized colors for $mode theme"
    
    # Create colors.css with proper @define-color declarations
    echo "/* Centralized Material You colors for all applications */" > "$colors_file"
    echo "" >> "$colors_file"
    echo "$colors_json" | jq -r ".colors.${mode} | to_entries[] | \"@define-color \\(.key) \\(.value);\"" >> "$colors_file"
    
    # Add compatibility aliases
    cat >> "$colors_file" << 'EOF'
@define-color foreground @on_surface;
@define-color accent @primary;
@define-color color7 @on_surface;
@define-color color9 @secondary;
EOF
    
    log_module "$module_name" "Generated colors file: $colors_file"

    # Restart waybar using systemd if running (more reliable than SIGUSR2)
    # COMMENTED OUT FOR DEBUGGING - waybar reload causing freezes
    # if pgrep -x waybar >/dev/null; then
    #     log_module "$module_name" "Restarting waybar via systemd"
    #     systemctl --user restart waybar 2>/dev/null || {
    #         # Fallback to pkill if systemd service not available
    #         log_module "$module_name" "Systemd service not found, restarting manually"
    #         pkill waybar
    #         sleep 0.2
    #         waybar &>/dev/null &
    #     }
    # else
    #     log_module "$module_name" "Waybar not running, no reload needed"
    # fi
    log_module "$module_name" "Waybar reload disabled for debugging"

    return 0
}
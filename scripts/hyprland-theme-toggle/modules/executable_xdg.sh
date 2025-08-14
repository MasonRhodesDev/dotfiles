#!/bin/bash

# XDG portal theme coordination module (implements solutions from Hyprland discussion #5867)

source "$(dirname "${BASH_SOURCE[0]}")/base.sh"

xdg_apply_theme() {
    local wallpaper="$1"
    local mode="$2" 
    local state_file="$3"
    
    local module_name="XDG"
    
    log_module "$module_name" "Coordinating $mode theme across XDG portals"
    
    # Check for required XDG portals
    local portals=(
        "xdg-desktop-portal-gtk"
        "xdg-desktop-portal-hyprland" 
        "xdg-desktop-portal-wlr"
    )
    
    local missing_portals=()
    for portal in "${portals[@]}"; do
        if ! app_installed "$portal"; then
            missing_portals+=("$portal")
        fi
    done
    
    if [[ ${#missing_portals[@]} -gt 0 ]]; then
        log_module "$module_name" "Missing XDG portals: ${missing_portals[*]}"
        log_module "$module_name" "Install with: sudo pacman -S ${missing_portals[*]}"
    fi
    
    # Restart xdg-desktop-portal to pick up theme changes
    if systemctl --user is-active --quiet xdg-desktop-portal; then
        log_module "$module_name" "Restarting xdg-desktop-portal service"
        systemctl --user restart xdg-desktop-portal
    fi
    
    # Set XDG environment variables for theme coordination
    export XDG_CURRENT_DESKTOP="Hyprland"
    systemctl --user set-environment XDG_CURRENT_DESKTOP="Hyprland"
    dbus-update-activation-environment --systemd XDG_CURRENT_DESKTOP="Hyprland"
    
    # Ensure color scheme is propagated through D-Bus
    if [[ "$mode" == "light" ]]; then
        gsettings set org.freedesktop.appearance color-scheme 1 2>/dev/null || true
    else
        gsettings set org.freedesktop.appearance color-scheme 2 2>/dev/null || true
    fi
    
    log_module "$module_name" "XDG portal coordination complete"
    
    return 0
}
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
    local required_backends=(
        "/usr/libexec/xdg-desktop-portal-gtk"
        "/usr/libexec/xdg-desktop-portal-hyprland"
    )
    
    local missing_backends=()
    for backend in "${required_backends[@]}"; do
        if [[ ! -f "$backend" ]]; then
            missing_backends+=("$(basename "$backend")")
        fi
    done
    
    if [[ ${#missing_backends[@]} -gt 0 ]]; then
        log_module "$module_name" "Missing XDG portal backends: ${missing_backends[*]}"
        log_module "$module_name" "Install with: sudo pacman -S ${missing_backends[*]}"
    else
        log_module "$module_name" "XDG portals configured: gtk (settings), hyprland (screen)"
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
    hyprctl setenv XDG_CURRENT_DESKTOP Hyprland
    
    # Ensure color scheme is propagated through D-Bus
    if [[ "$mode" == "light" ]]; then
        gsettings set org.gnome.desktop.interface color-scheme prefer-light 2>/dev/null || true
    else
        gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
    fi
    
    log_module "$module_name" "XDG portal coordination complete"
    
    return 0
}
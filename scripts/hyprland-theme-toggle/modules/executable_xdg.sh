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
    
    # Don't restart portal service - it disconnects Chromium's signal listener
    # Instead, just ensure the portal service is running
    if ! systemctl --user is-active --quiet xdg-desktop-portal; then
        log_module "$module_name" "Starting xdg-desktop-portal service"
        systemctl --user start xdg-desktop-portal
        sleep 1  # Give portal time to initialize
    else
        log_module "$module_name" "Portal service already running - preserving connections"
    fi
    
    # Set XDG environment variables for theme coordination
    export XDG_CURRENT_DESKTOP="Hyprland"
    export GTK_USE_PORTAL=1
    systemctl --user set-environment XDG_CURRENT_DESKTOP="Hyprland"
    systemctl --user set-environment GTK_USE_PORTAL=1
    dbus-update-activation-environment --systemd XDG_CURRENT_DESKTOP="Hyprland" GTK_USE_PORTAL=1
    hyprctl setenv XDG_CURRENT_DESKTOP Hyprland
    hyprctl setenv GTK_USE_PORTAL 1
    
    # GTK portal backend is READ-ONLY - it gets settings from gsettings/GTK config
    # We need to update the underlying settings that GTK portal reads from
    if [[ "$mode" == "light" ]]; then
        # Set gsettings (GTK portal reads from this)
        gsettings set org.gnome.desktop.interface color-scheme prefer-light 2>/dev/null || true
        
        # GTK portal doesn't support Write method, so we emit signal manually
        # Signal format must match what GTK portal would emit when settings change
        gdbus emit --session \
            --object-path /org/freedesktop/portal/desktop \
            --signal org.freedesktop.portal.Settings.SettingChanged \
            "org.freedesktop.appearance" \
            "color-scheme" \
            "<uint32 2>" 2>/dev/null || true
        
        log_module "$module_name" "Updated gsettings to light, emitted portal signal (2)"
    else
        # Set gsettings (GTK portal reads from this)
        gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
        
        # GTK portal doesn't support Write method, so we emit signal manually
        # Signal format must match what GTK portal would emit when settings change  
        gdbus emit --session \
            --object-path /org/freedesktop/portal/desktop \
            --signal org.freedesktop.portal.Settings.SettingChanged \
            "org.freedesktop.appearance" \
            "color-scheme" \
            "<uint32 1>" 2>/dev/null || true
        
        log_module "$module_name" "Updated gsettings to dark, emitted portal signal (1)"
    fi
    
    # Verify portal can respond to Read requests (GTK portal reads from gsettings)
    local portal_response=$(gdbus call --session \
        --dest org.freedesktop.portal.Desktop \
        --object-path /org/freedesktop/portal/desktop \
        --method org.freedesktop.portal.Settings.Read \
        "org.freedesktop.appearance" \
        "color-scheme" 2>/dev/null | grep -o 'uint32 [0-9]' || echo "")
    
    if [[ -n "$portal_response" ]]; then
        log_module "$module_name" "Portal Read verification: $portal_response"
    else
        log_module "$module_name" "Warning: Portal Read verification failed"
    fi
    
    log_module "$module_name" "XDG portal coordination complete"
    
    return 0
}
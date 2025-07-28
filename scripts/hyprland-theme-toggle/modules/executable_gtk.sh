#!/bin/bash

# GTK theme module

source "$(dirname "${BASH_SOURCE[0]}")/base.sh"

gtk_apply_theme() {
    local wallpaper="$1"
    local mode="$2"
    local state_file="$3"
    
    local module_name="GTK"
    
    log_module "$module_name" "Setting $mode theme via environment variables"
    
    # Set GTK theme environment variable
    local gtk_theme_var
    if [[ "$mode" == "light" ]]; then
        gtk_theme_var="Adwaita:light"
    else
        gtk_theme_var="Adwaita:dark"
    fi
    
    # Update environment variables for future app launches
    export GTK_THEME="$gtk_theme_var"
    
    # Update session environment via systemd
    systemctl --user set-environment GTK_THEME="$gtk_theme_var"
    
    # Update D-Bus environment  
    dbus-update-activation-environment --systemd GTK_THEME="$gtk_theme_var"
    
    # Set color-scheme preference (modern GNOME approach)
    gsettings set org.gnome.desktop.interface color-scheme "prefer-$mode"
    
    log_module "$module_name" "Environment updated with GTK_THEME=$gtk_theme_var"
    
    return 0
}
#!/bin/bash

# Qt theme module (implements solutions from Hyprland discussion #5867)

source "$(dirname "${BASH_SOURCE[0]}")/base.sh"

qt_apply_theme() {
    local wallpaper="$1"
    local mode="$2"
    local state_file="$3"
    
    local module_name="Qt"
    
    # Check if Qt6 configuration tools are available
    if ! app_installed "qt6ct"; then
        log_module "$module_name" "qt6ct not installed, skipping Qt theme switching"
        return 0
    fi
    
    log_module "$module_name" "Setting $mode theme for Qt applications"
    
    # Set Qt platform theme environment variable
    export QT_QPA_PLATFORMTHEME="qt6ct"
    systemctl --user set-environment QT_QPA_PLATFORMTHEME="qt6ct"
    dbus-update-activation-environment --systemd QT_QPA_PLATFORMTHEME="qt6ct"
    hyprctl setenv QT_QPA_PLATFORMTHEME qt6ct
    
    # Update Qt6ct configuration file if it exists
    local qt6ct_config="$HOME/.config/qt6ct/qt6ct.conf"
    if [[ -f "$qt6ct_config" ]]; then
        if [[ "$mode" == "light" ]]; then
            # Switch to light color scheme
            sed -i "s/color_scheme_path=.*/color_scheme_path=\/usr\/share\/color-schemes\/BreezeLight.colors/" "$qt6ct_config"
        else
            # Switch to dark color scheme  
            sed -i "s/color_scheme_path=.*/color_scheme_path=\/usr\/share\/color-schemes\/BreezeDark.colors/" "$qt6ct_config"
        fi
        log_module "$module_name" "Updated qt6ct configuration"
    else
        log_module "$module_name" "qt6ct.conf not found, Qt apps may not switch themes"
    fi
    
    # Also set for Qt5 if qt5ct is available
    if app_installed "qt5ct"; then
        export QT_QPA_PLATFORMTHEME="qt5ct"
        systemctl --user set-environment QT_QPA_PLATFORMTHEME="qt5ct"
        hyprctl setenv QT_QPA_PLATFORMTHEME qt5ct
        
        local qt5ct_config="$HOME/.config/qt5ct/qt5ct.conf"
        if [[ -f "$qt5ct_config" ]]; then
            if [[ "$mode" == "light" ]]; then
                sed -i "s/color_scheme_path=.*/color_scheme_path=\/usr\/share\/color-schemes\/BreezeLight.colors/" "$qt5ct_config"
            else
                sed -i "s/color_scheme_path=.*/color_scheme_path=\/usr\/share\/color-schemes\/BreezeDark.colors/" "$qt5ct_config"
            fi
            log_module "$module_name" "Updated qt5ct configuration"
        fi
    fi
    
    log_module "$module_name" "Qt theme environment updated"
    
    return 0
}
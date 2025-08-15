#!/bin/bash

# GTK theme module

source "$(dirname "${BASH_SOURCE[0]}")/base.sh"

gtk_apply_theme() {
    local wallpaper="$1"
    local mode="$2"
    local state_file="$3"
    
    local module_name="GTK"
    
    log_module "$module_name" "Setting $mode theme for GTK 3/4 applications"
    
    # Set GTK theme environment variable with proper theme name
    local gtk_theme_var
    if [[ "$mode" == "light" ]]; then
        gtk_theme_var="Adwaita"
    else
        gtk_theme_var="Adwaita-dark"
    fi
    
    # Update environment variables for future app launches
    export GTK_THEME="$gtk_theme_var"
    
    # Update session environment via systemd
    systemctl --user set-environment GTK_THEME="$gtk_theme_var"
    
    # Update D-Bus environment  
    dbus-update-activation-environment --systemd GTK_THEME="$gtk_theme_var"
    
    # Update Hyprland environment
    hyprctl setenv GTK_THEME "$gtk_theme_var" 2>/dev/null || true
    
    # Configure GTK 3 and GTK 4 via gsettings
    if command -v gsettings >/dev/null 2>&1; then
        # Set color-scheme preference (GTK 4 / libadwaita standard)
        gsettings set org.gnome.desktop.interface color-scheme "prefer-$mode" 2>/dev/null || true
        
        # Set GTK theme via gsettings (GTK 3 compatibility)
        if [[ "$mode" == "light" ]]; then
            gsettings set org.gnome.desktop.interface gtk-theme "Adwaita" 2>/dev/null || true
        else
            gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark" 2>/dev/null || true
        fi
        
        # Set application prefer dark theme (GTK 3 fallback)
        if [[ "$mode" == "dark" ]]; then
            gsettings set org.gnome.desktop.interface gtk-application-prefer-dark-theme true 2>/dev/null || true
        else
            gsettings set org.gnome.desktop.interface gtk-application-prefer-dark-theme false 2>/dev/null || true
        fi
    fi
    
    # Only create config files if they don't exist (avoid overriding user customizations)
    setup_gtk_config_files "$mode"
    
    log_module "$module_name" "Environment updated with GTK_THEME=$gtk_theme_var and gsettings"
    
    return 0
}

setup_gtk_config_files() {
    local mode="$1"
    local module_name="GTK-Config"
    
    # Only create basic config files if they don't already exist
    # This avoids overriding user configurations that might cause crashes
    
    # GTK 3 settings file (create only if missing)
    local gtk3_config="$HOME/.config/gtk-3.0/settings.ini"
    if [[ ! -f "$gtk3_config" ]]; then
        mkdir -p "$(dirname "$gtk3_config")"
        
        cat > "$gtk3_config" << EOF
[Settings]
gtk-application-prefer-dark-theme = $([[ "$mode" == "dark" ]] && echo "true" || echo "false")
EOF
        log_module "$module_name" "Created minimal GTK 3 config (dark-theme preference)"
    fi
    
    # GTK 4 settings file (create only if missing)  
    local gtk4_config="$HOME/.config/gtk-4.0/settings.ini"
    if [[ ! -f "$gtk4_config" ]]; then
        mkdir -p "$(dirname "$gtk4_config")"
        
        if [[ "$mode" == "dark" ]]; then
            cat > "$gtk4_config" << EOF
[AdwStyleManager]
color-scheme = ADW_COLOR_SCHEME_PREFER_DARK
EOF
        else
            cat > "$gtk4_config" << EOF
[AdwStyleManager]
color-scheme = ADW_COLOR_SCHEME_PREFER_LIGHT
EOF
        fi
        log_module "$module_name" "Created minimal GTK 4 config (libadwaita color scheme)"
    fi
}
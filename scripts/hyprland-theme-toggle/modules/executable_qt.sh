#!/bin/bash

# Qt theme module (implements solutions from Hyprland discussion #5867)

source "$(dirname "${BASH_SOURCE[0]}")/base.sh"

qt_apply_theme() {
    local wallpaper="$1"
    local mode="$2"
    local state_file="$3"
    
    local module_name="Qt"
    local colors_css="$HOME/.config/matugen/colors.css"
    
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
    hyprctl setenv QT_QPA_PLATFORMTHEME qt6ct 2>/dev/null || true
    
    # Generate Material You KDE color scheme
    local colorscheme_dir="$HOME/.local/share/color-schemes"
    mkdir -p "$colorscheme_dir"
    
    local scheme_file="$colorscheme_dir/MaterialYou$(echo "$mode" | sed 's/.*/\u&/').colors"
    
    if [[ -f "$colors_css" ]]; then
        generate_kde_colorscheme "$colors_css" "$mode" "$scheme_file"
        log_module "$module_name" "Generated Material You color scheme: $scheme_file"
    else
        log_module "$module_name" "Warning: colors.css not found, using fallback"
    fi
    
    # Create or update qt6ct configuration
    local qt6ct_config="$HOME/.config/qt6ct/qt6ct.conf"
    mkdir -p "$(dirname "$qt6ct_config")"
    
    if [[ ! -f "$qt6ct_config" ]]; then
        # Create new config
        cat > "$qt6ct_config" << EOF
[Appearance]
color_scheme_path=$scheme_file
custom_palette=false
icon_theme=Adwaita
standard_dialogs=default
style=Fusion

[Fonts]
fixed=@Variant(\0\0\0@\0\0\0\x16\0M\0o\0n\0o\0s\0p\0\x61\0\x63\0\x65@(\0\0\0\0\0\0\xff\xff\xff\xff\x5\x1\0\x32\x10)
general=@Variant(\0\0\0@\0\0\0\x12\0S\0\x61\0n\0s\0 \0S\0\x65\0r\0i\0\x66@$\0\0\0\0\0\0\xff\xff\xff\xff\x5\x1\0\x32\x10)

[Interface]
activate_item_on_single_click=1
buttonbox_layout=0
cursor_flash_time=1000
dialog_buttons_have_icons=1
double_click_interval=400
gui_effects=@Invalid()
keyboard_scheme=2
menus_have_icons=true
show_shortcuts_in_context_menus=true
stylesheets=@Invalid()
toolbutton_style=4
underline_shortcut=1
wheel_scroll_lines=3

[SettingsWindow]
geometry=@ByteArray()
EOF
        log_module "$module_name" "Created qt6ct.conf with Material You colors"
    else
        # Update existing config
        sed -i "s|color_scheme_path=.*|color_scheme_path=$scheme_file|" "$qt6ct_config"
        log_module "$module_name" "Updated qt6ct.conf to use Material You colors"
    fi
    
    # Also set for Qt5 if qt5ct is available
    if app_installed "qt5ct"; then
        local qt5ct_config="$HOME/.config/qt5ct/qt5ct.conf"
        mkdir -p "$(dirname "$qt5ct_config")"
        
        if [[ ! -f "$qt5ct_config" ]]; then
            # Create new Qt5 config
            cat > "$qt5ct_config" << EOF
[Appearance]
color_scheme_path=$scheme_file
custom_palette=false
icon_theme=Adwaita
standard_dialogs=default
style=Fusion
EOF
            log_module "$module_name" "Created qt5ct.conf with Material You colors"
        else
            sed -i "s|color_scheme_path=.*|color_scheme_path=$scheme_file|" "$qt5ct_config"
            log_module "$module_name" "Updated qt5ct.conf to use Material You colors"
        fi
    fi
    
    log_module "$module_name" "Qt theme configured with Material You colors"
    
    return 0
}
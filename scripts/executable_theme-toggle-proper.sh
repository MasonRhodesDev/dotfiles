#!/bin/bash

# Theme toggle script following Hyprland and GTK best practices
# Implements proper runtime theme switching with consideration for Electron app issues

THEME_STATE_FILE="$HOME/.cache/theme_state"
WALLPAPER_PATH=$(grep "env = WALLPAPER_PATH" "$HOME/.config/hypr/configs/env.conf" | cut -d',' -f2)

# Create required directories
mkdir -p "$HOME/.config/matugen"
mkdir -p "$HOME/.config/gtk-3.0"
mkdir -p "$HOME/.config/gtk-4.0"

# Function to get current theme state
get_current_theme() {
    if [[ -f "$THEME_STATE_FILE" ]]; then
        cat "$THEME_STATE_FILE"
    else
        echo "dark"  # Default to dark
    fi
}

# Function to generate app configs from matugen colors
generate_app_configs() {
    local mode="$1"
    
    if /home/mason/scripts/generate-theme-configs.py "$WALLPAPER_PATH" "$mode" >/dev/null 2>&1; then
        echo "✓ Generated app configs"
    else
        echo "✗ Failed to generate app configs"
    fi
}

# Function to set theme state
set_theme_state() {
    echo "$1" > "$THEME_STATE_FILE"
}

# Function to update GTK config files (following XDG specification)
update_gtk_configs() {
    local theme="$1"
    local mode="$2"
    
    # Update GTK3 settings.ini
    cat > "$HOME/.config/gtk-3.0/settings.ini" << EOF
[Settings]
gtk-theme-name=$theme
gtk-icon-theme-name=Adwaita
gtk-font-name=Sans 10
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=0
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
gtk-application-prefer-dark-theme=$([ "$mode" = "dark" ] && echo "1" || echo "0")
EOF

    # Update GTK4 settings.ini
    cat > "$HOME/.config/gtk-4.0/settings.ini" << EOF
[Settings]
gtk-theme-name=$theme
gtk-icon-theme-name=Adwaita
gtk-font-name=Sans 10
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme=$([ "$mode" = "dark" ] && echo "1" || echo "0")
EOF

    # Update GTK2 config
    cat > "$HOME/.gtkrc-2.0" << EOF
gtk-theme-name="$theme"
gtk-icon-theme-name="Adwaita"
gtk-font-name="Sans 10"
gtk-cursor-theme-name="Adwaita"
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=0
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle="hintslight"
gtk-xft-rgba="rgb"
EOF
}

# Function to apply runtime GTK theme changes (the problematic part for Electron)
apply_runtime_gtk_changes() {
    local gtk_theme="$1"
    local color_scheme="$2"
    
    echo "⚠ Applying runtime GTK changes (may affect Electron apps)..."
    
    # Use gsettings for runtime changes (as per Hyprland/GTK documentation)
    gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme "$color_scheme" 2>/dev/null || true
    
    # Update environment for new applications
    export GTK_THEME="$gtk_theme"
    export QT_STYLE_OVERRIDE="$gtk_theme"
    
    # Update dbus environment (required for Wayland/Hyprland)
    dbus-update-activation-environment --systemd GTK_THEME QT_STYLE_OVERRIDE 2>/dev/null || true
    
    # Update Hyprland environment
    hyprctl setenv GTK_THEME "$GTK_THEME" 2>/dev/null || true
    hyprctl setenv QT_STYLE_OVERRIDE "$QT_STYLE_OVERRIDE" 2>/dev/null || true
    
    # Signal desktop portal (for proper Wayland theme detection)
    gdbus call --session --dest org.freedesktop.portal.Desktop \
        --object-path /org/freedesktop/portal/desktop \
        --method org.freedesktop.portal.Settings.Read \
        org.freedesktop.appearance color-scheme >/dev/null 2>&1 || true
}

# Function to restart affected applications safely
restart_applications() {
    echo "🔄 Restarting applications..."
    
    # Restart HyprPanel (always safe)
    if pgrep -f hyprpanel >/dev/null; then
        pkill -TERM -f hyprpanel
        local count=0
        while pgrep -f hyprpanel >/dev/null && [ $count -lt 10 ]; do
            sleep 0.5
            count=$((count + 1))
        done
        pkill -KILL -f hyprpanel 2>/dev/null || true
    fi
    
    (uwsm app -- hyprpanel >/dev/null 2>&1) &
    sleep 2
    
    if pgrep -f hyprpanel >/dev/null; then
        echo "✓ HyprPanel restarted"
    else
        echo "⚠ HyprPanel restart failed"
    fi
    
    # Kill safe applications
    pkill wofi 2>/dev/null || true
    
    # Warn about Electron apps
    if pgrep -f "cursor|code|discord|slack|spotify" >/dev/null; then
        echo "⚠ Electron apps detected - restart them manually if theme doesn't apply"
    fi
}

# Function to switch to light mode
switch_to_light() {
    echo "🌞 Switching to light mode..."
    
    local gtk_theme="Breeze"
    local color_scheme="prefer-light"
    
    # Generate colors first
    if [[ -n "$WALLPAPER_PATH" && -f "$WALLPAPER_PATH" ]]; then
        matugen image "$WALLPAPER_PATH" -m light >/dev/null 2>&1
        generate_app_configs "light"
    fi
    
    # Update GTK config files (safe - affects new apps)
    update_gtk_configs "$gtk_theme" "light"
    echo "✓ Updated GTK configuration files"
    
    # Apply runtime changes (potentially problematic for Electron)
    if [[ "$1" != "--no-runtime" ]]; then
        apply_runtime_gtk_changes "$gtk_theme" "$color_scheme"
    else
        echo "⏭ Skipped runtime GTK changes (use --no-runtime flag)"
    fi
    
    # Update theme state
    set_theme_state "light"
    
    # Restart applications
    restart_applications
    
    echo "✅ Switched to light mode"
}

# Function to switch to dark mode  
switch_to_dark() {
    echo "🌙 Switching to dark mode..."
    
    local gtk_theme="Breeze-Dark"
    local color_scheme="prefer-dark"
    
    # Generate colors first
    if [[ -n "$WALLPAPER_PATH" && -f "$WALLPAPER_PATH" ]]; then
        matugen image "$WALLPAPER_PATH" -m dark >/dev/null 2>&1
        generate_app_configs "dark"
    fi
    
    # Update GTK config files (safe - affects new apps)
    update_gtk_configs "$gtk_theme" "dark"
    echo "✓ Updated GTK configuration files"
    
    # Apply runtime changes (potentially problematic for Electron)
    if [[ "$1" != "--no-runtime" ]]; then
        apply_runtime_gtk_changes "$gtk_theme" "$color_scheme"
    else
        echo "⏭ Skipped runtime GTK changes (use --no-runtime flag)"
    fi
    
    # Update theme state
    set_theme_state "dark"
    
    # Restart applications
    restart_applications
    
    echo "✅ Switched to dark mode"
}

# Main logic
current_theme=$(get_current_theme)

case "$1" in
    "light")
        switch_to_light "$2"
        ;;
    "dark")
        switch_to_dark "$2"
        ;;
    "toggle")
        if [[ "$current_theme" == "light" ]]; then
            switch_to_dark "$2"
        else
            switch_to_light "$2"
        fi
        ;;
    "toggle-safe")
        if [[ "$current_theme" == "light" ]]; then
            switch_to_dark "--no-runtime"
        else
            switch_to_light "--no-runtime"
        fi
        ;;
    "status")
        echo "$current_theme"
        ;;
    *)
        echo "Usage: $0 [light|dark|toggle|toggle-safe|status] [--no-runtime]"
        echo ""
        echo "Commands:"
        echo "  light        - Switch to light mode"
        echo "  dark         - Switch to dark mode"
        echo "  toggle       - Toggle between light and dark"
        echo "  toggle-safe  - Toggle without runtime changes (Electron-safe)"
        echo "  status       - Show current theme"
        echo ""
        echo "Options:"
        echo "  --no-runtime - Skip gsettings/dbus changes (safer for Electron apps)"
        echo ""
        echo "Note: Runtime GTK changes may cause Electron apps (Cursor, VSCode) to crash."
        echo "Use 'toggle-safe' or '--no-runtime' to avoid this issue."
        exit 1
        ;;
esac
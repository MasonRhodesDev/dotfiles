#!/bin/bash

# Theme toggle script - safe version with no app signals
# Switches GTK themes, generates matugen configs, but doesn't signal running apps

THEME_STATE_FILE="$HOME/.cache/theme_state"
WALLPAPER_PATH=$(grep "env = WALLPAPER_PATH" "$HOME/.config/hypr/configs/env.conf" | cut -d',' -f2)

# Create matugen config directory if it doesn't exist
mkdir -p "$HOME/.config/matugen"

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
    
    # Use the Python script to generate configs
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

# Function to switch to light mode
switch_to_light() {
    echo "🌞 Switching to light mode..."
    
    # Set GTK themes
    gsettings set org.gnome.desktop.interface gtk-theme "Breeze" 2>/dev/null
    gsettings set org.gnome.desktop.interface color-scheme "prefer-light" 2>/dev/null
    
    # Set environment variables for the current session
    export GTK_THEME="Breeze"
    export QT_STYLE_OVERRIDE="Breeze"
    
    # Generate light mode colors with matugen
    if [[ -n "$WALLPAPER_PATH" && -f "$WALLPAPER_PATH" ]]; then
        matugen image "$WALLPAPER_PATH" -m light >/dev/null 2>&1
        generate_app_configs "light"
    fi
    
    # Update theme state
    set_theme_state "light"
    
    # Reload applications (safe version)
    reload_applications_safe
}

# Function to switch to dark mode
switch_to_dark() {
    echo "🌙 Switching to dark mode..."
    
    # Set GTK themes
    gsettings set org.gnome.desktop.interface gtk-theme "Breeze-Dark" 2>/dev/null
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null
    
    # Set environment variables for the current session
    export GTK_THEME="Breeze-Dark"
    export QT_STYLE_OVERRIDE="Breeze-Dark"
    
    # Generate dark mode colors with matugen
    if [[ -n "$WALLPAPER_PATH" && -f "$WALLPAPER_PATH" ]]; then
        matugen image "$WALLPAPER_PATH" -m dark >/dev/null 2>&1
        generate_app_configs "dark"
    fi
    
    # Update theme state
    set_theme_state "dark"
    
    # Reload applications (safe version)
    reload_applications_safe
}

# Function to reload applications (safe - no signals to Electron apps)
reload_applications_safe() {
    echo "⚡ Updating system theme..."
    
    # Update the current session's environment
    export GTK_THEME
    export QT_STYLE_OVERRIDE
    
    # Update dbus environment for newly launched applications
    dbus-update-activation-environment --systemd GTK_THEME QT_STYLE_OVERRIDE 2>/dev/null || true
    
    # Update Hyprland's environment variables
    hyprctl setenv GTK_THEME "$GTK_THEME" 2>/dev/null || true
    hyprctl setenv QT_STYLE_OVERRIDE "$QT_STYLE_OVERRIDE" 2>/dev/null || true
    
    # Restart HyprPanel only
    pkill -f hyprpanel 2>/dev/null || true
    sleep 2
    uwsm app -- hyprpanel >/dev/null 2>&1 &
    sleep 1
    
    # Check if HyprPanel started
    if pgrep -f hyprpanel >/dev/null; then
        echo "✓ HyprPanel restarted"
    else
        echo "⚠ HyprPanel restart issue"
    fi
    
    # Only kill Wofi (it's safe to restart)
    pkill wofi 2>/dev/null || true
    
    # Send desktop portal theme change signal
    gdbus call --session --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop --method org.freedesktop.portal.Settings.Read org.freedesktop.appearance color-scheme >/dev/null 2>&1 || true
    
    # Desktop notification
    notify-send "Theme Toggle" "Switched to $(get_current_theme) mode - restart apps to apply" --icon=preferences-desktop-theme 2>/dev/null || true
    
    echo "✅ Theme switched! Restart applications to see changes."
    echo "💡 New applications will automatically use the new theme."
}

# Main toggle logic
current_theme=$(get_current_theme)

case "$1" in
    "light")
        switch_to_light
        ;;
    "dark")
        switch_to_dark
        ;;
    "toggle"|"")
        if [[ "$current_theme" == "light" ]]; then
            switch_to_dark
        else
            switch_to_light
        fi
        ;;
    "status")
        echo "$current_theme"
        ;;
    *)
        echo "Usage: $0 [light|dark|toggle|status]"
        echo "  light  - Switch to light mode"
        echo "  dark   - Switch to dark mode" 
        echo "  toggle - Toggle between light and dark (default)"
        echo "  status - Show current theme"
        echo ""
        echo "This safe version doesn't send signals to running apps."
        echo "Restart applications manually to apply theme changes."
        exit 1
        ;;
esac
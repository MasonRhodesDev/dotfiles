#!/bin/bash

# Theme toggle script - Cursor-safe version
# Minimizes changes that might affect running Electron apps

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

# Function to switch to light mode (Cursor-safe)
switch_to_light() {
    echo "🌞 Switching to light mode (Cursor-safe)..."
    
    # Generate light mode colors with matugen (this should be safe)
    if [[ -n "$WALLPAPER_PATH" && -f "$WALLPAPER_PATH" ]]; then
        matugen image "$WALLPAPER_PATH" -m light >/dev/null 2>&1
        generate_app_configs "light"
    fi
    
    # Update theme state
    set_theme_state "light"
    
    echo "⚠ Skipping GTK settings changes to protect Cursor"
    echo "💡 New applications will use light theme automatically"
    
    # Only restart HyprPanel (safe)
    restart_hyprpanel_only
}

# Function to switch to dark mode (Cursor-safe)
switch_to_dark() {
    echo "🌙 Switching to dark mode (Cursor-safe)..."
    
    # Generate dark mode colors with matugen (this should be safe)
    if [[ -n "$WALLPAPER_PATH" && -f "$WALLPAPER_PATH" ]]; then
        matugen image "$WALLPAPER_PATH" -m dark >/dev/null 2>&1
        generate_app_configs "dark"
    fi
    
    # Update theme state
    set_theme_state "dark"
    
    echo "⚠ Skipping GTK settings changes to protect Cursor"  
    echo "💡 New applications will use dark theme automatically"
    
    # Only restart HyprPanel (safe)
    restart_hyprpanel_only
}

# Function to restart only HyprPanel (minimal approach)
restart_hyprpanel_only() {
    echo "🔄 Restarting HyprPanel only..."
    
    # Gently restart HyprPanel
    if pgrep -f hyprpanel >/dev/null; then
        pkill -TERM -f hyprpanel
        
        # Wait for graceful shutdown
        local count=0
        while pgrep -f hyprpanel >/dev/null && [ $count -lt 10 ]; do
            sleep 0.5
            count=$((count + 1))
        done
        
        # Force kill if still running
        if pgrep -f hyprpanel >/dev/null; then
            pkill -KILL -f hyprpanel
            sleep 1
        fi
    fi
    
    # Start HyprPanel
    (uwsm app -- hyprpanel >/dev/null 2>&1) &
    sleep 2
    
    # Check if started
    if pgrep -f hyprpanel >/dev/null; then
        echo "✓ HyprPanel restarted"
    else
        echo "⚠ HyprPanel restart failed"
    fi
    
    # Only kill Wofi (safe)
    pkill wofi 2>/dev/null || true
    
    echo "✅ Cursor-safe theme switch complete!"
    echo "📝 To apply GTK theme changes, close and restart Cursor manually"
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
    "full")
        echo "Running full theme toggle (may affect Cursor)..."
        exec /home/mason/scripts/theme-toggle.sh toggle
        ;;
    *)
        echo "Usage: $0 [light|dark|toggle|status|full]"
        echo "  light  - Switch to light mode (Cursor-safe)"
        echo "  dark   - Switch to dark mode (Cursor-safe)"
        echo "  toggle - Toggle between light and dark (Cursor-safe)"
        echo "  status - Show current theme"
        echo "  full   - Run full theme toggle (may crash Cursor)"
        echo ""
        echo "This Cursor-safe version skips GTK settings changes."
        echo "Restart Cursor manually to apply theme changes."
        exit 1
        ;;
esac
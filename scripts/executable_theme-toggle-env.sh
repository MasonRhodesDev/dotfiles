#!/bin/bash

# Environment-based theme toggle (GNOME-style approach)
STATE_FILE="$HOME/.cache/theme_state"
CURRENT_STATE=$(cat "$STATE_FILE" 2>/dev/null || echo "dark")

if [ "$CURRENT_STATE" = "light" ]; then
    NEW_STATE="dark"
    GTK_THEME_VAR="Adwaita:dark"
    MATUGEN_MODE="dark"
else
    NEW_STATE="light" 
    GTK_THEME_VAR="Adwaita:light"
    MATUGEN_MODE="light"
fi

echo "Switching to $NEW_STATE mode using environment variables..."

# Update state file
echo "$NEW_STATE" > "$STATE_FILE"

# Generate matugen colors for the new mode
matugen image "$HOME/Pictures/forrest.png" --mode "$MATUGEN_MODE" --type scheme-expressive

# Generate application configs
python3 "$HOME/scripts/generate-theme-configs.py" "$HOME/Pictures/forrest.png" "$NEW_STATE"

# Update environment variables for future app launches
export GTK_THEME="$GTK_THEME_VAR"

# Update session environment via systemd
systemctl --user set-environment GTK_THEME="$GTK_THEME_VAR"

# Update D-Bus environment  
dbus-update-activation-environment --systemd GTK_THEME="$GTK_THEME_VAR"

# Set color-scheme preference (this is the modern approach)
gsettings set org.gnome.desktop.interface color-scheme "prefer-$NEW_STATE"

# Restart HyprPanel safely
pkill -f hyprpanel
sleep 2
hyprpanel &

echo "Theme switched to $NEW_STATE mode. New applications will use the updated theme."
echo "Note: Running Electron apps may need to be restarted to pick up the new theme."
#!/bin/bash

# Installation script for Hyprland Theme Toggle

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYPRPANEL_CONFIG="$HOME/.config/hyprpanel"

echo "Installing Hyprland Theme Toggle..."

# Make scripts executable
chmod +x "$SCRIPT_DIR/theme-toggle-modular.sh"
chmod +x "$SCRIPT_DIR/install.sh"

# Install HyprPanel module
if [ -d "$HYPRPANEL_CONFIG" ]; then
    echo "Installing HyprPanel module..."
    mkdir -p "$HYPRPANEL_CONFIG/modules"
    cp "$SCRIPT_DIR/hyprpanel-module.ts" "$HYPRPANEL_CONFIG/modules/theme-toggle.ts"
    echo "HyprPanel module installed to $HYPRPANEL_CONFIG/modules/theme-toggle.ts"
else
    echo "Warning: HyprPanel config directory not found at $HYPRPANEL_CONFIG"
fi

# Create keybind instruction
echo ""
echo "Installation complete!"
echo ""
echo "To add a keybind, add this line to your Hyprland config:"
echo "bind = SUPER, T, exec, $SCRIPT_DIR/theme-toggle-modular.sh"
echo ""
echo "To add the button to HyprPanel, add 'theme-toggle' to your layout in:"
echo "$HYPRPANEL_CONFIG/config.json"
echo ""
echo "Usage: $SCRIPT_DIR/theme-toggle-modular.sh"
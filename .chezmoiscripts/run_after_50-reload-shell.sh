#!/bin/bash

# Initialize theme system and reload shell configuration on every apply
# Runs theme toggle to generate all application theme files

THEME_STATE="$HOME/.cache/theme_state"
THEME_TOGGLE="$HOME/scripts/hyprland-theme-toggle/executable_theme-toggle-modular.sh"

# Check if theme toggle script exists
if [ ! -x "$THEME_TOGGLE" ]; then
    echo "Theme toggle script not found, skipping theme initialization"
    exit 0
fi

# Get current theme mode or default to dark
MODE="dark"
if [ -f "$THEME_STATE" ]; then
    MODE=$(cat "$THEME_STATE")
fi

echo "Initializing theme system with $MODE mode..."
"$THEME_TOGGLE" "$MODE"

echo "Theme initialization complete"

# Check if user groups changed and notify
CURRENT_GROUPS=$(id -Gn)
GROUPS_CACHE="$HOME/.cache/chezmoi-user-groups"

if [ -f "$GROUPS_CACHE" ]; then
    OLD_GROUPS=$(cat "$GROUPS_CACHE")
    if [ "$CURRENT_GROUPS" != "$OLD_GROUPS" ]; then
        echo ""
        echo "WARNING: User groups have changed!"
        echo "Old groups: $OLD_GROUPS"
        echo "New groups: $CURRENT_GROUPS"
        echo "You may need to log out and back in for group changes to take full effect."
        echo ""
    fi
fi

# Update groups cache
echo "$CURRENT_GROUPS" > "$GROUPS_CACHE"

# Reload shell configuration if running in fish or bash
if [ -n "$FISH_VERSION" ]; then
    echo "Reloading fish configuration..."
    exec fish
elif [ -n "$BASH_VERSION" ]; then
    echo "Reloading bash configuration..."
    exec bash
fi

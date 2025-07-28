#!/bin/bash

# Script to source the current theme environment variables
# Usage: source ~/scripts/source-theme-env.sh

THEME_STATE_FILE="$HOME/.cache/theme_state"

if [[ -f "$THEME_STATE_FILE" ]]; then
    current_theme=$(cat "$THEME_STATE_FILE")
else
    current_theme="dark"
fi

if [[ "$current_theme" == "light" ]]; then
    export GTK_THEME="Breeze"
    export QT_STYLE_OVERRIDE="Breeze"
else
    export GTK_THEME="Breeze-Dark"
    export QT_STYLE_OVERRIDE="Breeze-Dark"
fi

echo "Theme environment loaded: $current_theme mode"
echo "GTK_THEME=$GTK_THEME"
echo "QT_STYLE_OVERRIDE=$QT_STYLE_OVERRIDE"
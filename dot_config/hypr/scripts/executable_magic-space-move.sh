#!/usr/bin/env bash
# Move active window to magic space for current workspace and focus it

# Get current workspace ID
WS=$(hyprctl activeworkspace -j | jq -r '.id')

# Don't operate from special workspaces
if [[ "$WS" -lt 0 ]]; then
    exit 0
fi

# Move active window to special:N and focus it
hyprctl dispatch movetoworkspace "special:$WS"

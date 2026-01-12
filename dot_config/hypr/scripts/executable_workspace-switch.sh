#!/usr/bin/env bash
# Switch to workspace, closing any active special workspace first
TARGET_WS="$1"

# Get current active special workspace on focused monitor
SPECIAL=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .specialWorkspace.name // empty')

# If a special workspace is active, close it
if [[ -n "$SPECIAL" && "$SPECIAL" != "null" ]]; then
    SPECIAL_NAME="${SPECIAL#special:}"
    hyprctl dispatch togglespecialworkspace "$SPECIAL_NAME"
fi

# Switch to target workspace
hyprctl dispatch workspace "$TARGET_WS"

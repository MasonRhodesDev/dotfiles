#!/bin/bash

# Waybar module for idle inhibitor
# Returns JSON format for waybar custom module

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source base functions with error handling
if [[ -f "$SCRIPT_DIR/modules/base.sh" ]]; then
    source "$SCRIPT_DIR/modules/base.sh"
else
    # Fallback if base.sh not found
    STATE_FILE="/tmp/idle-inhibitor-state"
    get_state() {
        if [[ -f "$STATE_FILE" ]]; then
            cat "$STATE_FILE" 2>/dev/null || echo "0"
        else
            echo "0"
        fi
    }
fi

# Get current state
state=$(get_state)

# Determine display based on state
if [[ "$state" == "1" ]]; then
    # Inhibitor is active - screen won't go idle
    icon="󰅶"  # Eye open icon (nerd font)
    class="activated"
    tooltip="Idle inhibition active - screen will stay awake"
    text="$icon "
else
    # Inhibitor is inactive - normal idle behavior
    icon="󰾪"  # Eye closed icon (nerd font)
    class="deactivated"
    tooltip="Idle inhibition inactive - normal idle behavior"  
    text="$icon "
fi

# Output JSON for waybar with proper escaping
printf '{"text": "%s", "tooltip": "%s", "class": "%s"}\n' "$text" "$tooltip" "$class"
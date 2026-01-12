#!/usr/bin/env bash
# Toggle special workspace for current workspace with auto-dismiss on workspace change

# Get current workspace info
WS_JSON=$(hyprctl activeworkspace -j)
WS=$(echo "$WS_JSON" | jq -r '.id')
WS_NAME=$(echo "$WS_JSON" | jq -r '.name')

# If already on a special workspace, just close it and exit
if [[ "$WS_NAME" == special:* ]] || [[ "$WS" -lt 0 ]]; then
    # Extract the special workspace name and close it
    SPECIAL_NAME="${WS_NAME#special:}"
    hyprctl dispatch togglespecialworkspace "$SPECIAL_NAME"
    exit 0
fi

# Toggle the special workspace for current workspace
hyprctl dispatch togglespecialworkspace "$WS"

# Start background listener to auto-dismiss on any workspace change
(
    # Listen to Hyprland socket for workspace events
    socat -U - "UNIX-CONNECT:/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while read -r line; do
        # Match any workspace-related event
        if [[ "$line" =~ ^workspace|^activespecial|^focusedmon ]]; then
            # Close the special workspace we opened
            hyprctl dispatch togglespecialworkspace "$WS" 2>/dev/null
            exit 0
        fi
    done
) &

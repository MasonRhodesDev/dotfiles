#!/bin/bash
# Wrapper script to launch regreet with dynamic monitor following

# Wait for Hyprland to initialize
sleep 0.5

# Get active monitor
ACTIVE_MONITOR=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .name' | head -1)

# Launch regreet in background
regreet &
REGREET_PID=$!

# Wait a moment for window to appear
sleep 0.3

# Move regreet workspace to the active monitor and focus it
if [ -n "$ACTIVE_MONITOR" ]; then
    hyprctl dispatch moveworkspacetomonitor 1 "$ACTIVE_MONITOR" 2>/dev/null
    hyprctl dispatch workspace 1 2>/dev/null
fi

# Monitor focus changes and move regreet window dynamically
(
    socat -U - UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" 2>/dev/null | \
    grep --line-buffered "focusedmon>>" | \
    while IFS='>' read -r _ _ monitor_info; do
        MONITOR_NAME=$(echo "$monitor_info" | cut -d',' -f1)
        if [ -n "$MONITOR_NAME" ]; then
            hyprctl dispatch moveworkspacetomonitor 1 "$MONITOR_NAME" 2>/dev/null
            hyprctl dispatch workspace 1 2>/dev/null
        fi
    done
) &
MONITOR_PID=$!

# Wait for regreet to finish
wait $REGREET_PID

# Clean up monitor listener
kill $MONITOR_PID 2>/dev/null

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

# Focus workspace 1 on the active monitor (swaps if necessary)
if [ -n "$ACTIVE_MONITOR" ]; then
    hyprctl dispatch focusworkspaceoncurrentmonitor 1 2>/dev/null
fi

# Monitor focus changes and move regreet window dynamically
(
    socat -U - UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" 2>/dev/null | \
    grep --line-buffered "focusedmon>>" | \
    while read -r _; do
        hyprctl dispatch focusworkspaceoncurrentmonitor 1 2>/dev/null
    done
) &
MONITOR_PID=$!

# Wait for regreet to finish
wait $REGREET_PID

# Clean up monitor listener
kill $MONITOR_PID 2>/dev/null

#!/bin/bash
# Wrapper script to launch regreet with dynamic monitor following

# Wait for Hyprland to initialize
sleep 0.5

# Get monitor where the cursor is located
CURSOR_POS=$(hyprctl cursorpos 2>/dev/null | tr -d ' ')
CURSOR_X=$(echo "$CURSOR_POS" | cut -d',' -f1)
CURSOR_Y=$(echo "$CURSOR_POS" | cut -d',' -f2)

# Find the monitor containing the cursor position
ACTIVE_MONITOR=$(hyprctl monitors -j 2>/dev/null | jq -r --argjson cx "$CURSOR_X" --argjson cy "$CURSOR_Y" \
  '.[] | select($cx >= .x and $cx < (.x + .width) and $cy >= .y and $cy < (.y + .height)) | .name' | head -1)

# Fallback to first monitor if cursor detection fails
if [ -z "$ACTIVE_MONITOR" ]; then
    ACTIVE_MONITOR=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0].name')
fi

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
    while IFS='>' read -r _ _ monitor_info; do
        FOCUSED_MON=$(echo "$monitor_info" | cut -d',' -f1)
        WS1_MON=$(hyprctl workspaces -j 2>/dev/null | jq -r '.[] | select(.id == 1) | .monitor')

        # Only move workspace if it's not already on the focused monitor
        if [ "$FOCUSED_MON" != "$WS1_MON" ]; then
            hyprctl dispatch focusworkspaceoncurrentmonitor 1 2>/dev/null
        fi
    done
) &
MONITOR_PID=$!

# Wait for regreet to finish
wait $REGREET_PID

# Clean up monitor listener
kill $MONITOR_PID 2>/dev/null

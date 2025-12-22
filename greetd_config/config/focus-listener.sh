#!/bin/bash
# Listen for monitor focus changes and move regreet window to follow cursor

sleep 2  # Wait for Hyprland socket to be ready

# Use HYPRLAND_INSTANCE_SIGNATURE if available, otherwise find newest
if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
else
    SOCKET=$(ls -t "$XDG_RUNTIME_DIR"/hypr/*/.socket2.sock 2>/dev/null | head -1)
fi

[ -S "$SOCKET" ] && exec socat -U - UNIX-CONNECT:"$SOCKET" | \
    grep --line-buffered "focusedmon>>" | \
    while read line; do
        /usr/local/bin/hyprctl dispatch focusworkspaceoncurrentmonitor 1 2>/dev/null
    done

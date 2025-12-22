#!/bin/bash
exec 2>&1
exec > /home/greeter/launcher.log
set -x

echo "Starting launcher at $(date)"
echo "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
echo "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"

sleep 0.5

# Find the Hyprland socket
SOCKET_DIR=$(find "$XDG_RUNTIME_DIR/hypr" -maxdepth 1 -type d -name "*_*" 2>/dev/null | head -1)
echo "SOCKET_DIR=$SOCKET_DIR"

if [ -n "$SOCKET_DIR" ]; then
    SOCKET="$SOCKET_DIR/.socket2.sock"
    echo "SOCKET=$SOCKET"

    # Background listener for focus changes
    (
        socat -U - UNIX-CONNECT:"$SOCKET" 2>/dev/null | \
        grep --line-buffered "focusedmon>>" | \
        while read line; do
            /usr/local/bin/hyprctl dispatch focusworkspaceoncurrentmonitor 1 2>/dev/null
        done
    ) &
    MONITOR_PID=$!
    echo "MONITOR_PID=$MONITOR_PID"
fi

echo "About to run regreet"
# Run regreet in foreground (blocks until login completes)
regreet
REGREET_EXIT=$?
echo "regreet exited with $REGREET_EXIT"

# Cleanup and exit
[ -n "$MONITOR_PID" ] && kill $MONITOR_PID 2>/dev/null
echo "Calling hyprctl dispatch exit"
/usr/local/bin/hyprctl dispatch exit

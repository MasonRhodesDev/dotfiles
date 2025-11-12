#!/bin/bash
# Hyprland config reload listener
# Monitors Hyprland IPC for configreloaded events and restarts waybar
# Prevents waybar freeze from hyprctl reload (https://github.com/Alexays/Waybar/issues/4451)

set -euo pipefail

SCRIPT_NAME=$(basename "$0")
LOCKFILE="/tmp/${SCRIPT_NAME}.lock"

cleanup() {
    rm -f "$LOCKFILE"
    exit 0
}

# Singleton management
if [ -f "$LOCKFILE" ]; then
    old_pid=$(cat "$LOCKFILE")
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
        echo "Another instance is already running (PID: $old_pid)"
        exit 1
    fi
fi
echo $$ > "$LOCKFILE"
trap cleanup EXIT INT TERM

echo "Starting Hyprland config reload listener (PID: $$)"

# Check Hyprland is running
if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    echo "ERROR: HYPRLAND_INSTANCE_SIGNATURE not set"
    exit 1
fi

socket_path="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
if [[ ! -e "$socket_path" ]]; then
    echo "ERROR: Hyprland socket not found at $socket_path"
    exit 1
fi

echo "Monitoring Hyprland events via $socket_path"

# Listen for configreloaded events
socat -U - "UNIX-CONNECT:$socket_path" | while IFS= read -r line; do
    if [[ "$line" == "configreloaded>>" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Detected configreloaded event"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Restarting waybar in 1 second..."
        (sleep 1 && systemctl --user restart waybar) &
    fi
done

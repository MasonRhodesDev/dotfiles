#!/bin/bash
# Hyprland event listener
# Monitors Hyprland IPC for various events:
# - configreloaded: restarts waybar (prevents freeze from hyprctl reload)
# - monitor changes: sets XWayland primary to ultrawide

set -euo pipefail

SCRIPT_NAME=$(basename "$0")
LOCKFILE="/tmp/${SCRIPT_NAME}.lock"
XWAYLAND_PRIMARY_SCRIPT="$HOME/.config/hypr/scripts/set-xwayland-primary.sh"

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

echo "Starting Hyprland event listener (PID: $$)"

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

# Set XWayland primary on startup
if [[ -x "$XWAYLAND_PRIMARY_SCRIPT" ]]; then
    (sleep 2 && "$XWAYLAND_PRIMARY_SCRIPT") &
fi

# Listen for Hyprland events
socat -U - "UNIX-CONNECT:$socket_path" | while IFS= read -r line; do
    case "$line" in
        "configreloaded>>")
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Config reloaded, restarting waybar..."
            (sleep 1 && systemctl --user restart waybar) &
            ;;
        monitoradded\>\>*|monitorremoved\>\>*|monitoraddedv2\>\>*)
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Monitor change: $line"
            if [[ -x "$XWAYLAND_PRIMARY_SCRIPT" ]]; then
                (sleep 1 && "$XWAYLAND_PRIMARY_SCRIPT") &
            fi
            ;;
    esac
done

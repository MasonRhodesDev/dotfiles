#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/modules/base.sh"

if daemon_running; then
    emit_toggle
else
    echo "Warning: Daemon not running, updating inhibit directly"
    current_state=$(get_state)
    if [[ "$current_state" == "1" ]]; then
        set_state "0"
    else
        set_state "1"
    fi
    update_inhibit
    refresh_waybar
fi
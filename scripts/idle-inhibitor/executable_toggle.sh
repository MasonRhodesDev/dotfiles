#!/bin/bash

# Toggle idle inhibitor state
# Called when waybar module is clicked

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/modules/base.sh"

# Get current state
current_state=$(get_state)

# Toggle state
if [[ "$current_state" == "1" ]]; then
    new_state="0"
    echo "Disabling idle inhibitor"
else
    new_state="1"
    echo "Enabling idle inhibitor"
fi

# Update state
set_state "$new_state"

# Refresh waybar display immediately
refresh_waybar

# If daemon is running, it will pick up the state change automatically
# If daemon is not running, update inhibit directly
if ! daemon_running; then
    echo "Warning: Daemon not running, updating inhibit directly"
    update_inhibit
fi
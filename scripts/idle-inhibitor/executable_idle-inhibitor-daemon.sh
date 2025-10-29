#!/bin/bash

# Idle Inhibitor Daemon
# Manages persistent idle inhibitor state and monitors for lock events

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/modules/base.sh"

cleanup() {
    log_daemon "Daemon shutting down..."
    stop_inhibit
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

monitor_dbus_events() {
    log_daemon "Starting D-Bus event monitor"
    
    dbus-monitor --session "type='signal',interface='${DBUS_INTERFACE}'" 2>/dev/null | \
    while read -r line; do
        if echo "$line" | grep -q "member=Disable"; then
            log_daemon "D-Bus Disable signal received"
            set_state "0"
            stop_inhibit
            refresh_waybar
        elif echo "$line" | grep -q "member=Toggle"; then
            log_daemon "D-Bus Toggle signal received"
            current_state=$(get_state)
            if [[ "$current_state" == "1" ]]; then
                new_state="0"
            else
                new_state="1"
            fi
            set_state "$new_state"
            update_inhibit
            refresh_waybar
        elif echo "$line" | grep -q "member=SetState"; then
            read -r next_line
            if echo "$next_line" | grep -q "string"; then
                new_state=$(echo "$next_line" | sed -n 's/.*string "\([01]\)".*/\1/p')
                if [[ -n "$new_state" ]]; then
                    log_daemon "D-Bus SetState signal received: $new_state"
                    set_state "$new_state"
                    update_inhibit
                    refresh_waybar
                fi
            fi
        fi
    done
}

# Monitor for state changes and update inhibit accordingly
monitor_state_changes() {
    local last_state=$(get_state)
    
    while true; do
        local current_state=$(get_state)
        
        if [[ "$current_state" != "$last_state" ]]; then
            log_daemon "State changed from $last_state to $current_state"
            update_inhibit
            refresh_waybar
            last_state="$current_state"
        fi
        
        sleep 0.5
    done
}

main() {
    log_daemon "Starting idle inhibitor daemon"
    
    init_state
    
    monitor_dbus_events &
    monitor_state_changes &
    
    while true; do
        sleep 10
        
        local state=$(get_state)
        if [[ "$state" == "1" ]]; then
            if [[ -f "$INHIBIT_PID_FILE" ]]; then
                local pid=$(cat "$INHIBIT_PID_FILE")
                if ! kill -0 "$pid" 2>/dev/null; then
                    log_daemon "systemd-inhibit process died, restarting"
                    start_inhibit
                fi
            else
                log_daemon "No inhibit PID file found, restarting"
                start_inhibit
            fi
        fi
    done
}

# Check if already running
if daemon_running; then
    existing_pid=$(pgrep -f "idle-inhibitor-daemon.sh" | head -1)
    if [[ "$existing_pid" != "$$" ]]; then
        echo "Daemon already running with PID $existing_pid"
        exit 1
    fi
fi

# Start main daemon
main
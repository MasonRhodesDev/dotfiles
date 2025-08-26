#!/bin/bash

# Idle Inhibitor Daemon
# Manages persistent idle inhibitor state and monitors for lock events

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/modules/base.sh"

LOCK_SIGNAL_FILE="/tmp/idle-inhibitor-lock-signal"

# Handle termination signals
cleanup() {
    log_daemon "Daemon shutting down..."
    stop_inhibit
    rm -f "$LOCK_SIGNAL_FILE"
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Monitor for lock events via signal file
monitor_lock_events() {
    while true; do
        if [[ -f "$LOCK_SIGNAL_FILE" ]]; then
            log_daemon "Lock event detected - disabling idle inhibitor"
            set_state "0"
            stop_inhibit
            refresh_waybar
            rm -f "$LOCK_SIGNAL_FILE"
        fi
        sleep 1
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

# Main daemon function
main() {
    log_daemon "Starting idle inhibitor daemon"
    
    # Initialize state to OFF on startup
    init_state
    
    # Start background monitors
    monitor_lock_events &
    monitor_state_changes &
    
    # Keep daemon alive
    while true; do
        sleep 10
        
        # Verify systemd-inhibit is still running if state is ON
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
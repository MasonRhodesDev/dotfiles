#!/bin/bash

STATE_FILE="/tmp/idle-inhibitor-state"
INHIBIT_PID_FILE="/tmp/idle-inhibitor-systemd.pid"

DBUS_SERVICE="com.idleinhibitor.Control"
DBUS_PATH="/com/idleinhibitor/Control"
DBUS_INTERFACE="com.idleinhibitor.Control"

# Get current idle inhibitor state
get_state() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Set idle inhibitor state
set_state() {
    local state="$1"
    echo "$state" > "$STATE_FILE"
}

# Start systemd inhibit for idle prevention
start_inhibit() {
    # Don't start if already running
    if [[ -f "$INHIBIT_PID_FILE" ]] && kill -0 "$(cat "$INHIBIT_PID_FILE")" 2>/dev/null; then
        return 0
    fi
    
    # Start systemd-inhibit in background
    systemd-inhibit --what=idle --who="waybar-idle-inhibitor" --why="User requested idle inhibition" sleep infinity &
    local pid=$!
    echo "$pid" > "$INHIBIT_PID_FILE"
    
    # Verify it started successfully
    if kill -0 "$pid" 2>/dev/null; then
        return 0
    else
        rm -f "$INHIBIT_PID_FILE"
        return 1
    fi
}

# Stop systemd inhibit
stop_inhibit() {
    if [[ -f "$INHIBIT_PID_FILE" ]]; then
        local pid=$(cat "$INHIBIT_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
        fi
        rm -f "$INHIBIT_PID_FILE"
    fi
}

# Update inhibit based on state
update_inhibit() {
    local state=$(get_state)
    
    if [[ "$state" == "1" ]]; then
        start_inhibit
    else
        stop_inhibit
    fi
}

# Send signal to waybar to refresh idle inhibitor display
refresh_waybar() {
    pkill -SIGRTMIN+9 waybar
}

# Log function for daemon messages
log_daemon() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

# Check if daemon is running
daemon_running() {
    pgrep -f "idle-inhibitor-daemon.sh" >/dev/null
}

# Initialize state (called on startup)
init_state() {
    # Always start with inhibitor OFF on daemon startup
    set_state "0"
    stop_inhibit
    log_daemon "Initialized with idle inhibitor OFF"
}

emit_disable() {
    dbus-send --session --type=signal "$DBUS_PATH" "${DBUS_INTERFACE}.Disable" 2>/dev/null || true
}

emit_toggle() {
    dbus-send --session --type=signal "$DBUS_PATH" "${DBUS_INTERFACE}.Toggle" 2>/dev/null || true
}

emit_set_state() {
    local state="$1"
    dbus-send --session --type=signal "$DBUS_PATH" "${DBUS_INTERFACE}.SetState" string:"$state" 2>/dev/null || true
}
#!/bin/bash

STATE_FILE="/tmp/screen-recorder-state"
PIDFILE="/tmp/gpu-screen-recorder.pid"

get_recording_pid() {
    if [[ -f "$PIDFILE" ]]; then
        cat "$PIDFILE" 2>/dev/null
    fi
}

is_recording() {
    local pid=$(get_recording_pid)
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        return 0
    fi
    # Clean up stale PID file
    if [[ -f "$PIDFILE" ]]; then
        rm -f "$PIDFILE" "$STATE_FILE"
    fi
    return 1
}

get_output_file() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE" 2>/dev/null
    fi
}

set_output_file() {
    local filename="$1"
    echo "$filename" > "$STATE_FILE"
}

clear_state() {
    rm -f "$STATE_FILE" "$PIDFILE"
}

refresh_waybar() {
    pkill -SIGRTMIN+10 waybar
}

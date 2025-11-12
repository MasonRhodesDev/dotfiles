#!/bin/bash

# Event-based monitor management for Hyprland
# Manages eDP display based on lid state and external monitor presence

SCRIPT_NAME=$(basename "$0")
LOCKFILE="/tmp/${SCRIPT_NAME}.lock"
EDP_MONITOR="eDP-2"
CONF_FILE="$HOME/.config/hypr/configs/monitors.conf"

# Singleton management - kill other instances
manage_singleton() {
    if [ -f "$LOCKFILE" ]; then
        local old_pid=$(cat "$LOCKFILE")
        if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
            echo "Stopping previous instance (PID: $old_pid)"
            kill "$old_pid" 2>/dev/null
            sleep 0.5
        fi
    fi
    echo $$ > "$LOCKFILE"
    trap cleanup EXIT INT TERM
}

cleanup() {
    rm -f "$LOCKFILE"
    exit 0
}

# Get lid state
get_lid_state() {
    local state=$(cat /proc/acpi/button/lid/*/state 2>/dev/null | awk '{print $2}')
    [[ "$state" == "open" ]] && echo "open" || echo "closed"
}

# Check if any external monitors are connected
has_external_monitors() {
    local external_count=$(hyprctl monitors -j | jq '[.[] | select(.name != "'"$EDP_MONITOR"'")] | length')
    [[ "$external_count" -gt 0 ]]
}

# Get eDP configuration from monitors.conf
get_edp_config() {
    local config_line=$(grep -E "^monitor\s*=\s*$EDP_MONITOR" "$CONF_FILE" 2>/dev/null || echo "")
    if [[ -z "$config_line" ]]; then
        echo "$EDP_MONITOR,preferred,auto,1"
    else
        echo "$config_line" | sed 's/^monitor\s*=\s*//'
    fi
}

# Apply monitor configuration
apply_monitor_config() {
    local lid_state="$1"
    local has_external="$2"
    
    echo "State: lid=$lid_state, external=$has_external"
    
    case "${lid_state}_${has_external}" in
        "closed_false")
            # State 1: no external monitors, lid closed = screen off
            hyprctl keyword monitor "$EDP_MONITOR,disable"
            ;;
        "closed_true")
            # State 2: external monitors, lid closed = internal screen disabled
            hyprctl keyword monitor "$EDP_MONITOR,disable"
            ;;
        "open_true")
            # State 3: external monitors, lid open = screen on, positioned left
            local edp_config=$(get_edp_config)
            hyprctl keyword monitor "$edp_config"
            ;;
        "open_false")
            # State 4: no external monitors, lid open = screen on
            local edp_config=$(get_edp_config)
            hyprctl keyword monitor "$edp_config"
            ;;
    esac
}

# Process current state
process_state() {
    local lid_state=$(get_lid_state)
    local has_external
    has_external_monitors && has_external="true" || has_external="false"
    
    apply_monitor_config "$lid_state" "$has_external"
}

# Handle Hyprland events
handle_hyprland_event() {
    local event="$1"
    case "$event" in
        monitoradded*|monitorremoved*|monitoraddedv2*)
            echo "Monitor change: $event"
            process_state
            ;;
    esac
}

# Handle ACPI events (lid switch)
monitor_lid_events() {
    acpi_listen 2>/dev/null | while IFS= read -r line; do
        if echo "$line" | grep -q "button/lid"; then
            echo "Lid event: $line"
            sleep 0.1  # Brief delay to let hardware settle
            process_state
        fi
    done
}

# Main execution
main() {
    manage_singleton
    
    echo "Starting monitor management (PID: $$)"
    echo "eDP monitor: $EDP_MONITOR"
    
    # Check dependencies
    if ! command -v acpi_listen >/dev/null 2>&1; then
        echo "Warning: acpi_listen not found. Lid detection may not work."
    fi
    
    # Start lid monitoring in background
    monitor_lid_events &
    LID_MONITOR_PID=$!
    
    # Monitor Hyprland events
    if [[ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
        echo "Error: HYPRLAND_INSTANCE_SIGNATURE not set"
        exit 1
    fi
    
    local socket_path="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
    if [[ ! -e "$socket_path" ]]; then
        echo "Error: Hyprland socket not found at $socket_path"
        exit 1
    fi
    
    echo "Monitoring events via $socket_path"
    
    # Process initial state after socket connection is confirmed
    process_state
    
    # Enhanced cleanup function
    cleanup() {
        echo "Cleaning up..."
        [[ -n "$LID_MONITOR_PID" ]] && kill "$LID_MONITOR_PID" 2>/dev/null
        rm -f "$LOCKFILE"
        exit 0
    }
    trap cleanup EXIT INT TERM
    
    # Listen for Hyprland events
    socat -U - "UNIX-CONNECT:$socket_path" | while IFS= read -r line; do
        handle_hyprland_event "$line"
    done
}

main "$@"
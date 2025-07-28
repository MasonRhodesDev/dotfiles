#!/bin/bash

# Script to monitor controller middle button press and launch Steam

# Required packages: evtest
if ! command -v evtest &> /dev/null; then
    echo "Error: evtest not installed. Please install with package manager."
    exit 1
fi

# Find all potential controller devices
DEVICES=$(find /dev/input/by-id/ -name "*event-joystick*")

if [ -z "$DEVICES" ]; then
    echo "No controller devices found"
    exit 1
fi

# Monitor all controller devices for middle button press
monitor_controllers() {
    for device in $DEVICES; do
        # Start monitoring in background
        (
            evtest "$device" | while read -r line; do
                # Look for middle button press (typically button code 2)
                if echo "$line" | grep -q "type 1 (EV_KEY), code 2 (BTN_MIDDLE), value 1"; then
                    echo "Middle button pressed on controller $device"
                    # Launch Steam as game_user
                    systemctl start steam-session@game_user.service
                    break
                fi
            done
        ) &
    done
    wait
}

# Run the monitor
monitor_controllers 
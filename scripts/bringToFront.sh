#!/bin/bash
# File: bringToFront.sh

# Replace 'executable_name' with the name of the executable you're looking for
executable_name="$1"

# Get the list of running windows
windows_list=$(wmctrl -lx)

# Find the window corresponding to the specified executable
window_id=$(echo "$windows_list" | grep "$executable_name" | awk '{print $1}')

# Activate the window
if [ -n "$window_id" ]; then
    wmctrl -ia "$window_id"
else
    echo "Window not found"
fi


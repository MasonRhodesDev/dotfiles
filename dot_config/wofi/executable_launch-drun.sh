#!/bin/bash

# Check if wofi is already running
if pgrep -x "wofi" > /dev/null; then
    # If wofi is running, kill it to toggle
    pkill -x "wofi"
    exit 0
fi

# Launch wofi drun mode
app=$(wofi --show drun --term wezterm --allow-images -W 800 -D key_expand=Tab -i 2>/dev/null)

# If an app was selected, launch it
if [ -n "$app" ]; then
    uwsm app -- "$app" >/dev/null 2>&1 &
fi
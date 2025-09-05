#!/bin/bash

# Redirect all output to prevent any command interpretation
exec 1>/dev/null 2>&1

# Check if wofi is already running
if pgrep -x "wofi" > /dev/null; then
    # If wofi is running, kill it to toggle
    pkill -x "wofi"
    exit 0
fi

# Launch wofi in drun mode with desktop file output
# This outputs the path to the .desktop file instead of executing the app
desktop_file=$(wofi --show drun --term wezterm --allow-images -W 800 -D key_expand=Tab -i --define drun-print_desktop_file=true 2>/dev/null)

# If a desktop file was selected, launch it properly with uwsm
if [ -n "$desktop_file" ]; then
    # uwsm app handles desktop files correctly and manages systemd integration
    uwsm app -- "$desktop_file" &
fi
#!/bin/bash

# Chezmoi Daemon Trigger - Manual trigger for the chezmoi daemon
# Author: Mason Rhodes

DAEMON_SCRIPT="{{ .chezmoi.homeDir }}/scripts/chezmoi-daemon.sh"

# Check if daemon script exists
if [ ! -f "$DAEMON_SCRIPT" ]; then
    echo "Error: Daemon script not found at $DAEMON_SCRIPT"
    echo "Please run the installer first."
    exit 1
fi

echo "Triggering chezmoi change detection..."

# Call the daemon with trigger mode
"$DAEMON_SCRIPT" trigger "$@"
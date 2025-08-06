#!/bin/bash

# Chezmoi Daemon Installer
# Author: Mason Rhodes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="$HOME"
SCRIPTS_DIR="$HOME_DIR/scripts"
CONFIG_DIR="$HOME_DIR/.config"
SYSTEMD_USER_DIR="$CONFIG_DIR/systemd/user"

echo "=== Chezmoi Daemon Installer ==="
echo "Installing chezmoi daemon system..."

# Create necessary directories
echo "Creating directories..."
mkdir -p "$SCRIPTS_DIR"
mkdir -p "$SYSTEMD_USER_DIR"
mkdir -p "$HOME_DIR/.cache/chezmoi-daemon"

# Install daemon script
echo "Installing daemon script..."
if [ -f "$SCRIPT_DIR/src/daemon.sh" ]; then
    # Process template variables
    sed "s|{{ .chezmoi.homeDir }}|$HOME_DIR|g; s|{{ .chezmoi.username }}|$USER|g" \
        "$SCRIPT_DIR/src/daemon.sh" > "$SCRIPTS_DIR/chezmoi-daemon.sh"
    chmod +x "$SCRIPTS_DIR/chezmoi-daemon.sh"
    echo "  ✓ Daemon script installed to $SCRIPTS_DIR/chezmoi-daemon.sh"
else
    echo "  ✗ Error: daemon.sh not found in $SCRIPT_DIR/src/"
    exit 1
fi

# Install trigger script
echo "Installing trigger script..."
if [ -f "$SCRIPT_DIR/src/trigger.sh" ]; then
    # Process template variables
    sed "s|{{ .chezmoi.homeDir }}|$HOME_DIR|g; s|{{ .chezmoi.username }}|$USER|g" \
        "$SCRIPT_DIR/src/trigger.sh" > "$SCRIPTS_DIR/chezmoi-trigger.sh"
    chmod +x "$SCRIPTS_DIR/chezmoi-trigger.sh"
    echo "  ✓ Trigger script installed to $SCRIPTS_DIR/chezmoi-trigger.sh"
else
    echo "  ✗ Error: trigger.sh not found in $SCRIPT_DIR/src/"
    exit 1
fi

# Install systemd service files
echo "Installing systemd service files..."
if [ -f "$SCRIPT_DIR/systemd/chezmoi-daemon.service" ]; then
    # Process template variables
    sed "s|{{ .chezmoi.homeDir }}|$HOME_DIR|g; s|{{ .chezmoi.username }}|$USER|g" \
        "$SCRIPT_DIR/systemd/chezmoi-daemon.service" > "$SYSTEMD_USER_DIR/chezmoi-daemon.service"
    echo "  ✓ Service file installed to $SYSTEMD_USER_DIR/chezmoi-daemon.service"
else
    echo "  ✗ Error: chezmoi-daemon.service not found in $SCRIPT_DIR/systemd/"
    exit 1
fi

if [ -f "$SCRIPT_DIR/systemd/chezmoi-daemon.timer" ]; then
    # Process template variables
    sed "s|{{ .chezmoi.homeDir }}|$HOME_DIR|g; s|{{ .chezmoi.username }}|$USER|g" \
        "$SCRIPT_DIR/systemd/chezmoi-daemon.timer" > "$SYSTEMD_USER_DIR/chezmoi-daemon.timer"
    echo "  ✓ Timer file installed to $SYSTEMD_USER_DIR/chezmoi-daemon.timer"
else
    echo "  ✗ Error: chezmoi-daemon.timer not found in $SCRIPT_DIR/systemd/"
    exit 1
fi

# Reload systemd and enable services
echo "Setting up systemd services..."
systemctl --user daemon-reload
systemctl --user enable chezmoi-daemon.timer
systemctl --user start chezmoi-daemon.timer
echo "  ✓ Systemd timer enabled and started"

# Set up triggers (desktop autostart and hyprland)
echo "Setting up login triggers..."
"$SCRIPTS_DIR/chezmoi-daemon.sh" setup

echo ""
echo "=== Installation Complete ==="
echo "Chezmoi daemon has been installed successfully!"
echo ""
echo "Available commands:"
echo "  $SCRIPTS_DIR/chezmoi-trigger.sh        - Manual trigger"
echo "  $SCRIPTS_DIR/chezmoi-daemon.sh check   - Check for changes once"
echo "  $SCRIPTS_DIR/chezmoi-daemon.sh daemon  - Run in daemon mode"
echo ""
echo "The daemon will automatically:"
echo "  • Check for changes on login (via autostart)"
echo "  • Check for changes hourly (via systemd timer)"
echo "  • Show desktop notifications when changes are detected"
echo ""
echo "Logs are available at: ~/.cache/chezmoi-daemon/daemon.log"
#!/bin/bash

# Chezmoi Daemon Uninstaller
# Author: Mason Rhodes

set -e

HOME_DIR="$HOME"
SCRIPTS_DIR="$HOME_DIR/scripts"
CONFIG_DIR="$HOME_DIR/.config"
SYSTEMD_USER_DIR="$CONFIG_DIR/systemd/user"
AUTOSTART_DIR="$CONFIG_DIR/autostart"
CACHE_DIR="$HOME_DIR/.cache/chezmoi-daemon"

echo "=== Chezmoi Daemon Uninstaller ==="
echo "Removing chezmoi daemon system..."

# Stop and disable systemd services
echo "Stopping systemd services..."
if systemctl --user is-active --quiet chezmoi-daemon.timer; then
    systemctl --user stop chezmoi-daemon.timer
    echo "  ✓ Stopped chezmoi-daemon.timer"
fi

if systemctl --user is-enabled --quiet chezmoi-daemon.timer; then
    systemctl --user disable chezmoi-daemon.timer
    echo "  ✓ Disabled chezmoi-daemon.timer"
fi

if systemctl --user is-enabled --quiet chezmoi-daemon.service; then
    systemctl --user disable chezmoi-daemon.service
    echo "  ✓ Disabled chezmoi-daemon.service"
fi

# Remove systemd service files
echo "Removing systemd service files..."
if [ -f "$SYSTEMD_USER_DIR/chezmoi-daemon.service" ]; then
    rm -f "$SYSTEMD_USER_DIR/chezmoi-daemon.service"
    echo "  ✓ Removed chezmoi-daemon.service"
fi

if [ -f "$SYSTEMD_USER_DIR/chezmoi-daemon.timer" ]; then
    rm -f "$SYSTEMD_USER_DIR/chezmoi-daemon.timer"
    echo "  ✓ Removed chezmoi-daemon.timer"
fi

# Reload systemd
systemctl --user daemon-reload
echo "  ✓ Reloaded systemd"

# Remove script files
echo "Removing script files..."
if [ -f "$SCRIPTS_DIR/chezmoi-daemon.sh" ]; then
    rm -f "$SCRIPTS_DIR/chezmoi-daemon.sh"
    echo "  ✓ Removed chezmoi-daemon.sh"
fi

if [ -f "$SCRIPTS_DIR/chezmoi-trigger.sh" ]; then
    rm -f "$SCRIPTS_DIR/chezmoi-trigger.sh"
    echo "  ✓ Removed chezmoi-trigger.sh"
fi

# Remove autostart entry
echo "Removing autostart entry..."
if [ -f "$AUTOSTART_DIR/chezmoi-daemon-trigger.desktop" ]; then
    rm -f "$AUTOSTART_DIR/chezmoi-daemon-trigger.desktop"
    echo "  ✓ Removed autostart entry"
fi

# Remove Hyprland exec-once line
echo "Removing Hyprland configuration..."
HYPR_CONFIG="$CONFIG_DIR/hypr/hyprland.conf"
if [ -f "$HYPR_CONFIG" ] && grep -q "chezmoi-daemon.sh" "$HYPR_CONFIG"; then
    # Create a backup first
    cp "$HYPR_CONFIG" "$HYPR_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    # Remove the line
    grep -v "chezmoi-daemon.sh" "$HYPR_CONFIG" > "$HYPR_CONFIG.tmp" && mv "$HYPR_CONFIG.tmp" "$HYPR_CONFIG"
    echo "  ✓ Removed Hyprland exec-once entry (backup created)"
fi

# Ask about cache directory
echo ""
read -p "Remove daemon cache directory ($CACHE_DIR)? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -d "$CACHE_DIR" ]; then
        rm -rf "$CACHE_DIR"
        echo "  ✓ Removed cache directory"
    fi
else
    echo "  ✓ Kept cache directory (contains logs and ignore hash)"
fi

echo ""
echo "=== Uninstallation Complete ==="
echo "Chezmoi daemon has been removed successfully!"
echo ""
if [ -d "$CACHE_DIR" ]; then
    echo "Note: Cache directory preserved at $CACHE_DIR"
    echo "      (contains logs and ignore hash)"
fi
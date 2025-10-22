#!/bin/bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/__helpers.sh"

echo "=== Installing Hyprland Ecosystem ==="

install_packages_from_registry "hyprland"

if ! command -v hyprls > /dev/null 2>&1; then
    echo "Installing hyprls language server..."
    
    if [ "$(get_distro)" = "fedora" ]; then
        sudo dnf install -y bison gcc make
        
        if ! command -v gvm > /dev/null 2>&1; then
            bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
        fi
        source ~/.gvm/scripts/gvm || true
        
        gvm install go1.20.6 || true
        gvm use go1.20.6 || true
        
        gvm install go1.23.4 || true
        gvm use go1.23.4 --default || true
        
    elif [ "$(get_distro)" = "arch" ]; then
        sudo pacman -S --needed --noconfirm go
    fi
    
    go install github.com/ewen-lbh/hyprls/cmd/hyprls@latest
    
    if command -v hyprls > /dev/null 2>&1; then
        sudo ln -sf $(which hyprls) /usr/local/bin/hyprls || true
    fi
fi

if systemctl --user list-unit-files | grep -q waybar-reload.path; then
    echo "Enabling waybar auto-reload service..."
    systemctl --user enable waybar-reload.path || true
    systemctl --user start waybar-reload.path || true
fi

echo "=== Installing Web Browsers ==="

install_packages_from_registry "browsers"

echo "Setting default browser..."
DISTRO=$(get_distro)
if [ "$DISTRO" = "fedora" ]; then
    xdg-settings set default-web-browser vivaldi-stable.desktop 2>/dev/null || true
elif [ "$DISTRO" = "arch" ]; then
    xdg-settings set default-web-browser vivaldi-stable.desktop 2>/dev/null || true
fi

echo "✓ Hyprland and browser installation complete!"

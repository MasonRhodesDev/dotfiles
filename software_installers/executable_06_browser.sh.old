#!/bin/sh
set -eu

# Platform detection
if command -v dnf > /dev/null 2>&1; then
    PACKAGE_MANAGER="dnf"
elif command -v pacman > /dev/null 2>&1; then
    PACKAGE_MANAGER="pacman"
else
    echo "Error: Unsupported system. This script requires Fedora or Arch Linux."
    exit 1
fi

# Install web browsers
echo "Installing web browsers..."

if [ "$PACKAGE_MANAGER" = "dnf" ]; then
    # Vivaldi browser
    if ! command -v vivaldi > /dev/null 2>&1; then
        echo "Installing Vivaldi Browser..."
        sudo dnf install -y vivaldi-stable
        xdg-settings set default-web-browser vivaldi-stable.desktop 2>/dev/null || true
    fi
    
    # Additional browsers
    if ! command -v chromium > /dev/null 2>&1; then
        echo "Installing Chromium..."
        sudo dnf install -y chromium
    fi
    
elif [ "$PACKAGE_MANAGER" = "pacman" ]; then
    # Vivaldi browser
    if ! command -v vivaldi > /dev/null 2>&1; then
        echo "Installing Vivaldi Browser..."
        yay -S --noconfirm vivaldi
        xdg-settings set default-web-browser vivaldi-stable.desktop 2>/dev/null || true
    fi
    
    # Additional browsers from official repos
    if ! command -v chromium > /dev/null 2>&1; then
        echo "Installing Chromium..."
        sudo pacman -S --noconfirm chromium
    fi
    
    if ! command -v firefox > /dev/null 2>&1; then
        echo "Installing Firefox..."
        sudo pacman -S --noconfirm firefox
    fi
fi

echo "Web browser installation complete!"
exit 0

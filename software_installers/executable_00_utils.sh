#!/bin/sh
set -eu

# Platform detection
if command -v dnf > /dev/null 2>&1; then
    PACKAGE_MANAGER="dnf"
    echo "Detected Fedora Linux"
elif command -v pacman > /dev/null 2>&1; then
    PACKAGE_MANAGER="pacman"
    echo "Detected Arch Linux"
else
    echo "Error: Unsupported system. This script requires Fedora or Arch Linux."
    exit 1
fi

# Install core utilities
echo "Installing core utilities..."

if [ "$PACKAGE_MANAGER" = "dnf" ]; then
    # Fedora packages
    sudo dnf install -y \
        vim curl git jq \
        thunar \
        solaar \
        wireplumber \
        NetworkManager \
        go \
        gcc-go \
        keychain \
        powerline-fonts \
        fira-code-fonts \
        piper \
        headsetcontrol

    # Enable COPR for Hyprland
    sudo dnf copr enable solopasha/hyprland -y
    
elif [ "$PACKAGE_MANAGER" = "pacman" ]; then
    # Install yay if not present
    if ! command -v yay > /dev/null 2>&1; then
        echo "Installing yay AUR helper..."
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        cd /tmp/yay
        makepkg -si --noconfirm
        cd -
        rm -rf /tmp/yay
    fi
    
    # Arch packages
    sudo pacman -S --noconfirm \
        vim curl git jq \
        thunar \
        wireplumber \
        networkmanager \
        go \
        keychain
        
    # AUR packages
    yay -S --noconfirm \
        solaar \
        ttf-fira-code \
        piper \
        headsetcontrol
fi

# Create udev rules for headset control
echo "Setting up udev rules for headset control..."
sudo tee /etc/udev/rules.d/70-headset.rules << 'EOF'
# SteelSeries Arctis Nova 7
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1038", ATTRS{idProduct}=="2202", MODE="0666"
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1038", ATTRS{idProduct}=="12ad", MODE="0666"

# General SteelSeries devices
SUBSYSTEM=="usb", ATTRS{idVendor}=="1038", MODE="0666"
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1038", MODE="0666"
EOF

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger

echo "Core utilities installation complete!"
exit 0
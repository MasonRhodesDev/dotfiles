#!/bin/bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/__helpers.sh"

echo "=== Installing Core Utilities ==="

install_packages_from_registry "core_utils"

echo "Setting up udev rules for headset control..."
sudo tee /etc/udev/rules.d/70-headset.rules << 'EOF'
# SteelSeries Arctis Nova 7
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1038", ATTRS{idProduct}=="2202", MODE="0666"
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1038", ATTRS{idProduct}=="12ad", MODE="0666"

# General SteelSeries devices
SUBSYSTEM=="usb", ATTRS{idVendor}=="1038", MODE="0666"
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1038", MODE="0666"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger

echo "✓ Core utilities installation complete!"

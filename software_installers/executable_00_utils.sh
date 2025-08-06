#!/bin/sh
set -eu

# Utils
echo "Installing Utils"
sudo dnf install -y vim curl git jq Thunar solaar wireplumber NetworkManager go gcc-go keychain powerline-fonts fira-code-fonts piper headsetcontrol

# Create udev rules for headset control
echo "Setting up udev rules for headset control"
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

if ! command -v brew &> /dev/null; then
    #Install Brew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# source brew
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

#Install oh-my-posh
brew install oh-my-posh

# add solopasha/hyprland source to dnf
sudo dnf copr enable solopasha/hyprland -y

exit 0
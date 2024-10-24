#!/bin/sh
set -eu

# hyprland
if ! command -v hyprland &> /dev/null; then
    echo "Installing Hyprland Tooling"
    sudo dnf install -y hyprcursor.x86_64 hyprcursor-devel.x86_64 hypridle.x86_64 hyprland.x86_64 hyprland-devel.x86_64 hyprland-protocols-devel.noarch hyprlang.x86_64 hyprlang-devel.x86_64 hyprlock.x86_64 hyprpicker.x86_64 hyprutils.x86_64 hyprutils-devel.x86_64 hyprwayland-scanner-devel.x86_64 xdg-desktop-portal-hyprland.x86_64 
    sudo dnf install -y wofi waybar dunst
fi

exit 0

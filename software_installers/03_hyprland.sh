#!/bin/bash
set -e

# hyprland
if ! command -v hyprland &> /dev/null; then
    echo "Installing Hyprland Tooling"
    sudo dnf install -y hyprcursor.x86_64 hyprcursor-devel.x86_64 hypridle.x86_64 hyprland.x86_64 hyprland-devel.x86_64 hyprland-protocols-devel.noarch hyprlang.x86_64 hyprlang-devel.x86_64 hyprlock.x86_64 hyprpicker.x86_64 hyprutils.x86_64 hyprutils-devel.x86_64 hyprwayland-scanner-devel.x86_64 xdg-desktop-portal-hyprland.x86_64 
    sudo dnf install -y wofi waybar dunst pavucontrol swaybg
fi

if  ! command -v hyprls &> /dev/null; then
    sudo dnf install -y bison gcc make

    # Install gvm
    if ! command -v gvm &> /dev/null; then
        bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
    fi
    source ~/.gvm/scripts/gvm

    gvm install go1.20.6
    # Then use it
    gvm use go1.20.6

    # Install latest stable Go version
    gvm install go1.23.4
    gvm use go1.23.4 --default

    go install github.com/ewen-lbh/hyprls/cmd/hyprls@latest

    # make hyprls globally available using which hyprls
    sudo ln -s $(which hyprls) /usr/local/bin/hyprls
fi


exit 0

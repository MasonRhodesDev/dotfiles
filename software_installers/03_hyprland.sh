#!/bin/bash

source "$(dirname "$0")/__helpers.sh"

echo "Installing Hyprland ecosystem..."

if [ "$(get_distro)" = "fedora" ]; then
    # Fedora: Install via DNF
    install_packages \
        "hyprcursor hypridle hyprland hyprland-protocols-devel hyprlang hyprlock hyprpicker hyprutils xdg-desktop-portal-hyprland wofi pavucontrol swaybg" \
        ""
    
    # Install development tools for hyprls
    install_packages "bison gcc make" ""
    
    # Install Go and hyprls
    if ! command -v go &> /dev/null; then
        install_packages "golang" ""
    fi
    
    # Install hyprls if not present
    if ! command -v hyprls &> /dev/null; then
        echo "Installing hyprls..."
        go install github.com/ewen-lbh/hyprls@latest
    fi

elif [ "$(get_distro)" = "arch" ]; then
    # Arch: Install via yay with -git variants
    install_aur_packages \
        "hyprcursor-git hypridle-git hyprland-git hyprland-protocols-git hyprlang-git hyprlock-git hyprpicker-git hyprutils-git xdg-desktop-portal-hyprland-git wofi pavucontrol swaybg hyprls-git"
fi

# Install hyprpanel (cross-distro via AUR for Arch, manual for Fedora)
if [ "$(get_distro)" = "arch" ]; then
    install_aur_packages "hyprpanel-git"
elif [ "$(get_distro)" = "fedora" ]; then
    if ! command -v hyprpanel &> /dev/null; then
        echo "Installing hyprpanel..."
        # Install Node.js if not present (needed for hyprpanel)
        install_packages "nodejs npm" ""
        
        # Clone and build hyprpanel
        temp_dir="/tmp/hyprpanel"
        git clone https://github.com/Jas-SinghFSU/HyprPanel.git "$temp_dir"
        cd "$temp_dir"
        npm install
        npm run build
        
        # Install globally (you may need to adjust this path)
        sudo npm install -g .
        cd -
        rm -rf "$temp_dir"
    fi
fi

echo "Hyprland ecosystem installation complete!"
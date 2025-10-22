#!/bin/bash
set -e

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

# Install Hyprland ecosystem
if ! command -v hyprland > /dev/null 2>&1; then
    echo "Installing Hyprland ecosystem..."
    
    if [ "$PACKAGE_MANAGER" = "dnf" ]; then
        # Enable COPR repos for Hyprland
        sudo dnf copr enable -y solopasha/hyprland
        sudo dnf copr enable -y heus-sueh/packages
        
        # Set priority for heus-sueh packages repo
        if ! grep -q "priority=200" /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:heus-sueh:packages.repo 2>/dev/null; then
            sudo sh -c 'echo "priority=200" >> /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:heus-sueh:packages.repo'
        fi
        
        # Install Hyprland and tools
        sudo dnf install -y \
            hyprcursor hyprcursor-devel \
            hypridle \
            hyprland hyprland-devel hyprland-protocols-devel \
            hyprlang hyprlang-devel \
            hyprlock \
            hyprpicker \
            hyprutils hyprutils-devel \
            hyprwayland-scanner-devel \
            xdg-desktop-portal-hyprland
            
        # Desktop environment tools
        sudo dnf install -y wofi waybar dunst pavucontrol swaybg
        
    elif [ "$PACKAGE_MANAGER" = "pacman" ]; then
        # Install from official repos and AUR
        sudo pacman -S --noconfirm \
            hyprland \
            waybar wofi \
            dunst pavucontrol \
            xdg-desktop-portal-hyprland \
            wl-clipboard grim slurp
            
        # AUR packages (prefer -git versions as requested)
        yay -S --noconfirm \
            hyprlock-git \
            hypridle-git \
            hyprpicker-git \
            swaybg-git \
            matugen \
            swaync-git \
            swayosd-git
    fi
    
    # Enable waybar auto-reload service if available
    if systemctl --user list-unit-files | grep -q waybar-reload.path; then
        echo "Enabling waybar auto-reload service..."
        systemctl --user enable waybar-reload.path
        systemctl --user start waybar-reload.path
    fi
fi

# Install hyprls language server
if ! command -v hyprls > /dev/null 2>&1; then
    echo "Installing hyprls language server..."
    
    if [ "$PACKAGE_MANAGER" = "dnf" ]; then
        sudo dnf install -y bison gcc make
        
        # Install gvm for Go version management
        if ! command -v gvm > /dev/null 2>&1; then
            bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
        fi
        source ~/.gvm/scripts/gvm
        
        gvm install go1.20.6
        gvm use go1.20.6
        
        # Install latest stable Go version
        gvm install go1.23.4
        gvm use go1.23.4 --default
        
    elif [ "$PACKAGE_MANAGER" = "pacman" ]; then
        sudo pacman -S --noconfirm go
    fi
    
    # Install hyprls
    go install github.com/ewen-lbh/hyprls/cmd/hyprls@latest
    
    # Make hyprls globally available
    if command -v hyprls > /dev/null 2>&1; then
        sudo ln -s $(which hyprls) /usr/local/bin/hyprls
    fi
fi

echo "Hyprland ecosystem installation complete!"
exit 0

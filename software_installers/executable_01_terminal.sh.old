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

# Terminal applications
if ! command -v foot > /dev/null 2>&1 || ! command -v tmux > /dev/null 2>&1; then
    echo "Installing terminal applications..."
    
    if [ "$PACKAGE_MANAGER" = "dnf" ]; then
        sudo dnf install -y foot tmux
    elif [ "$PACKAGE_MANAGER" = "pacman" ]; then
        sudo pacman -S --noconfirm foot tmux
    fi
fi

# Oh My Posh
if ! command -v oh-my-posh > /dev/null 2>&1; then
    echo "Installing Oh My Posh..."
    
    if [ "$PACKAGE_MANAGER" = "dnf" ]; then
        # Use universal installer on Fedora
        curl -s https://ohmyposh.dev/install.sh | bash -s
    elif [ "$PACKAGE_MANAGER" = "pacman" ]; then
        # Use AUR package on Arch
        yay -S --noconfirm oh-my-posh-bin
    fi
fi

echo "Terminal tools installation complete!"
exit 0

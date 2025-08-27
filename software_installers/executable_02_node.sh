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

# Install fnm (Fast Node Manager)
if ! command -v fnm > /dev/null 2>&1; then
    echo "Installing fnm (Fast Node Manager)..."
    
    if [ "$PACKAGE_MANAGER" = "dnf" ]; then
        # Use cargo to install fnm on Fedora
        if ! command -v cargo > /dev/null 2>&1; then
            sudo dnf install -y cargo
        fi
        cargo install fnm
    elif [ "$PACKAGE_MANAGER" = "pacman" ]; then
        # Install from AUR on Arch
        yay -S --noconfirm fnm-bin
    fi
    
    # Add fnm to shell profile if not already present
    if ! grep -q 'fnm env' ~/.bashrc 2>/dev/null; then
        echo 'eval "$(fnm env --use-on-cd)"' >> ~/.bashrc
    fi
fi

# Install latest LTS Node.js via fnm
if command -v fnm > /dev/null 2>&1; then
    echo "Installing Node.js LTS via fnm..."
    eval "$(fnm env --use-on-cd)"
    fnm install --lts
    fnm use lts-latest
    fnm default lts-latest
fi

# Bun runtime
if ! command -v bun > /dev/null 2>&1; then
    echo "Installing Bun..."
    
    if [ "$PACKAGE_MANAGER" = "dnf" ]; then
        curl -fsSL https://bun.sh/install | bash
    elif [ "$PACKAGE_MANAGER" = "pacman" ]; then
        yay -S --noconfirm bun-bin
    fi
fi

echo "Node.js development tools installation complete!"
echo "Note: Restart your shell or run 'source ~/.bashrc' to use fnm"
exit 0

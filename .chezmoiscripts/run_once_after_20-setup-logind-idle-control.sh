#!/bin/bash

echo "Setting up logind-idle-control..."

# Ensure build tools are installed
if ! command -v make &>/dev/null || ! command -v cargo &>/dev/null; then
    echo "Installing build dependencies..."
    if command -v dnf &>/dev/null; then
        sudo dnf install -y make gcc gcc-c++ automake autoconf pkg-config cargo
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm base-devel rust
    else
        echo "Unsupported package manager, cannot install build tools"
        exit 0
    fi
fi

REPO_DIR="$HOME/repos/logind-idle-control"

if [ ! -d "$REPO_DIR" ]; then
    echo "Cloning logind-idle-control repository..."
    mkdir -p "$HOME/repos"
    git clone https://github.com/MasonRhodesDev/logind-idle-control.git "$REPO_DIR"
    echo "Repository cloned successfully"
else
    echo "Repository already exists at $REPO_DIR"
fi

echo "Installing logind-idle-control..."
cd "$REPO_DIR"
make install

echo "logind-idle-control setup complete!"

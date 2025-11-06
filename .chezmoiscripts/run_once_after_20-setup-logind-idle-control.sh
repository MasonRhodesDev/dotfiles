#!/bin/bash
set -e

echo "Setting up logind-idle-control..."

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

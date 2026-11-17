#!/bin/bash
set -eu

BASH_PATH=/bin/bash
CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)

if [ "$CURRENT_SHELL" != "$BASH_PATH" ]; then
    echo "Setting default shell to bash..."
    sudo chsh -s "$BASH_PATH" "$USER"
    echo "✓ Default shell set to bash"
else
    echo "✓ Default shell is already bash"
fi

#!/bin/bash
set -eu

# Set fish as default shell if installed
if command -v fish &> /dev/null; then
    FISH_PATH=$(command -v fish)
    CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)

    if [ "$CURRENT_SHELL" != "$FISH_PATH" ]; then
        echo "Setting default shell to fish..."

        # Ensure fish is in /etc/shells
        if ! grep -q "^$FISH_PATH$" /etc/shells; then
            echo "$FISH_PATH" | sudo tee -a /etc/shells > /dev/null
        fi

        # Change default shell
        sudo chsh -s "$FISH_PATH" "$USER"
        echo "✓ Default shell set to fish"
        echo "  Log out and back in for changes to take effect"
    else
        echo "✓ Default shell is already fish"
    fi
else
    echo "⚠ Fish not installed, skipping default shell setup"
fi

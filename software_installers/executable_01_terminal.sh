#!/bin/sh
set -eu

# Terminal
if ! command -v foot &> /dev/null || ! command -v tmux &> /dev/null; then
    echo "Installing Terminal tools"
    sudo dnf install -y foot tmux
fi

# Oh My Posh
if ! command -v oh-my-posh &> /dev/null; then
    echo "Installing Oh My Posh"
    curl -s https://ohmyposh.dev/install.sh | bash -s
fi

exit 0

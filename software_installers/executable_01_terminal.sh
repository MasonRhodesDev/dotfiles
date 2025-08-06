#!/bin/sh
set -eu

# Terminal
if ! command -v foot &> /dev/null || ! command -v tmux &> /dev/null; then
    echo "Installing Terminal tools"
    sudo dnf install -y foot tmux
fi

exit 0

#!/bin/bash

source "$(dirname "$0")/__helpers.sh"

echo "Installing terminal tools..."

# Install WezTerm and tmux
install_packages \
    "wezterm tmux" \
    "wezterm tmux"

echo "Terminal tools installation complete!"
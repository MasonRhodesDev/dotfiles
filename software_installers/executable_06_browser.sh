#!/bin/sh
set -eu

if ! command -v vivaldi &> /dev/null; then
    echo "Installing Vivaldi Browser"
    sudo dnf install -y vivaldi
    xdg-settings set default-web-browser vivaldi.desktop
fi

exit 0

#!/bin/bash

source "$(dirname "$0")/__helpers.sh"

echo "Installing browsers..."

# Install Vivaldi
if ! command -v vivaldi &> /dev/null; then
    echo "Installing Vivaldi..."
    
    if [ "$(get_distro)" = "fedora" ]; then
        install_packages "vivaldi-stable" ""
    elif [ "$(get_distro)" = "arch" ]; then
        install_aur_packages "vivaldi"
    fi
    
    # Set Vivaldi as default browser
    if command -v xdg-settings &> /dev/null; then
        xdg-settings set default-web-browser vivaldi-stable.desktop
    fi
fi

echo "Browser installation complete!"
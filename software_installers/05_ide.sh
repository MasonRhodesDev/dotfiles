#!/bin/sh
set -eu

# VSCode
if ! command -v code &> /dev/null; then
    echo "Installing VSCode"
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null

    sudo dnf install -y code # or code-insiders
fi

exit 0


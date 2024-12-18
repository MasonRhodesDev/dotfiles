#!/bin/sh
set -eu

# Node
if ! command -v node &> /dev/null; then
    echo "Installing NodeJS tooling"
    sudo dnf install -y nodejs
fi

if ! command -v bun &> /dev/null; then
    echo "Installing Bun"
    curl -fsSL https://bun.sh/install | bash
fi

if ! command -v nvm &> /dev/null; then
    echo "Installing NodeJS tooling"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi

exit 0

#!/bin/bash

source "$(dirname "$0")/__helpers.sh"

echo "Installing Node.js tools..."

# Install Node.js
install_packages \
    "nodejs npm" \
    "nodejs npm"

# Install fnm (Fast Node Manager) if not present
if ! command -v fnm &> /dev/null; then
    echo "Installing fnm..."
    curl -fsSL https://fnm.vercel.app/install | bash
    
    # Source fnm for current session
    export PATH="{{ .chezmoi.homeDir }}/.local/share/fnm:$PATH"
    eval "$(fnm env)"
fi

# Install Bun if not present
if ! command -v bun &> /dev/null; then
    echo "Installing Bun..."
    curl -fsSL https://bun.sh/install | bash
fi

echo "Node.js tools installation complete!"
#!/bin/bash
# Clone and install hyprstate on a fresh machine.
# Source: https://github.com/MasonRhodesDev/hyprstate
# Idempotent — safe to re-run.

set -euo pipefail

REPO_URL="git@github.com:MasonRhodesDev/hyprstate.git"
INSTALL_DIR="$HOME/repos/hyprstate"

echo "=== hyprstate: clone + install ==="

# Already running? Done.
if systemctl --user is-active hyprstate.service >/dev/null 2>&1; then
    echo "hyprstate.service already active — skipping"
    exit 0
fi

# Clone or update.
if [ ! -d "$INSTALL_DIR/.git" ]; then
    mkdir -p "$(dirname "$INSTALL_DIR")"
    echo "Cloning $REPO_URL -> $INSTALL_DIR"
    git clone "$REPO_URL" "$INSTALL_DIR"
else
    echo "Already cloned at $INSTALL_DIR; pulling latest"
    git -C "$INSTALL_DIR" pull --ff-only || echo "WARN: pull failed — continuing with local copy"
fi

# Run installer (handles symlinks, systemd unit, udev rule, migrations from
# any predecessor stack — including the old hypr-power name).
cd "$INSTALL_DIR"
./install.sh

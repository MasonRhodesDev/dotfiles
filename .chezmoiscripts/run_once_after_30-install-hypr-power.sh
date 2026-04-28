#!/bin/bash
# Clone and install hypr-power on a fresh machine.
# Source: https://github.com/MasonRhodesDev/hypr-power
# Idempotent — safe to re-run.

set -euo pipefail

REPO_URL="git@github.com:MasonRhodesDev/hypr-power.git"
INSTALL_DIR="$HOME/repos/hypr-power"

echo "=== hypr-power: clone + install ==="

# Already running? Done.
if systemctl --user is-active hypr-power.service >/dev/null 2>&1; then
    echo "hypr-power.service already active — skipping"
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
# any predecessor stack).
cd "$INSTALL_DIR"
./install.sh

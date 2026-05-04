#!/bin/bash
# Clone, build, and install hyprnotice on a fresh machine.
# Source: https://github.com/MasonRhodesDev/hyprnotice
# Idempotent — safe to re-run.

set -euo pipefail

REPO_URL="git@github.com:MasonRhodesDev/hyprnotice.git"
INSTALL_DIR="$HOME/repos/hyprnotice"

echo "=== hyprnotice: clone + build + install ==="

# Already running? Done.
if systemctl --user is-active hyprnotice.service >/dev/null 2>&1; then
    echo "hyprnotice.service already active — skipping"
    exit 0
fi

# Clone or update.
if [ ! -d "$INSTALL_DIR/.git" ]; then
    mkdir -p "$(dirname "$INSTALL_DIR")"
    echo "Cloning $REPO_URL -> $INSTALL_DIR"
    git clone "$REPO_URL" "$INSTALL_DIR"
else
    echo "Already cloned at $INSTALL_DIR; pulling latest"
    git -C "$INSTALL_DIR" pull --ff-only || echo "WARN: pull failed — continuing"
fi

cd "$INSTALL_DIR"

# Build (CMake + Ninja-or-Make).
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)"

# Run installer (symlinks, systemd unit, mako D-Bus disable).
./install.sh

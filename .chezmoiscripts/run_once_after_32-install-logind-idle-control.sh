#!/bin/bash
# Build + install logind-idle-control (+ tray) and enable its user units.
# Mirrors run_once_after_30-install-hyprstate.sh. Idempotent.
# Source: https://github.com/MasonRhodesDev/logind-idle-control
# (Its Makefile already enables the units; the enable below is a harmless no-op.)
set -euo pipefail

if command -v logind-idle-control >/dev/null 2>&1; then
    echo "logind-idle-control already installed — skipping"; exit 0
fi
if ! command -v cargo >/dev/null 2>&1; then
    echo "cargo not found — install the Rust toolchain first; skipping"; exit 0
fi

REPO="$HOME/repos/logind-idle-control"
URL="https://github.com/MasonRhodesDev/logind-idle-control.git"
if [ -d "$REPO/.git" ]; then git -C "$REPO" pull --ff-only || true; else git clone "$URL" "$REPO"; fi

echo "Building logind-idle-control (niced)..."
( cd "$REPO" && nice -n 19 make install )
systemctl --user enable --now logind-idle-control.service logind-idle-control-tray.service || true
echo "logind-idle-control installed + enabled. Logs: journalctl --user -u logind-idle-control"

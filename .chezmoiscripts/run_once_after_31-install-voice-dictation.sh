#!/bin/bash
# Build + install voice-dictation (first-party Rust app) and enable its user
# unit. Mirrors run_once_after_30-install-hyprstate.sh. Idempotent.
# Source: https://github.com/MasonRhodesDev/hyprland-voice-dictation
# (Its Makefile installs the unit but does NOT enable it, so we enable here.)
set -euo pipefail

if command -v voice-dictation >/dev/null 2>&1; then
    echo "voice-dictation already installed — skipping"; exit 0
fi
if ! command -v cargo >/dev/null 2>&1; then
    echo "cargo not found — install the Rust toolchain first; skipping"; exit 0
fi

REPO="$HOME/repos/hyprland-voice-dictation"
URL="https://github.com/MasonRhodesDev/hyprland-voice-dictation.git"
if [ -d "$REPO/.git" ]; then git -C "$REPO" pull --ff-only || true; else git clone "$URL" "$REPO"; fi

echo "Building voice-dictation (niced; pulls a speech model, this is the heavy one)..."
( cd "$REPO" && nice -n 19 make install )
systemctl --user enable --now voice-dictation.service || true
echo "voice-dictation installed + enabled. Logs: journalctl --user -u voice-dictation"

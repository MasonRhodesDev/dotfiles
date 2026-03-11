#!/bin/bash
set -eu

# Enable automatic GNOME Keyring unlock on login via PAM
# Without this, apps like Chromium prompt for the keyring password on every session

if command -v authselect &> /dev/null; then
    if authselect list-features local 2>/dev/null | grep -q "with-pam-gnome-keyring"; then
        CURRENT=$(authselect current 2>/dev/null || true)
        if echo "$CURRENT" | grep -q "with-pam-gnome-keyring"; then
            echo "✓ GNOME Keyring PAM auto-unlock already enabled"
        else
            echo "Enabling GNOME Keyring PAM auto-unlock..."
            sudo authselect enable-feature with-pam-gnome-keyring
            echo "✓ GNOME Keyring will auto-unlock on next login"
        fi
    else
        echo "⚠ authselect profile does not support with-pam-gnome-keyring feature"
    fi
else
    echo "⚠ authselect not found, skipping keyring PAM setup"
fi

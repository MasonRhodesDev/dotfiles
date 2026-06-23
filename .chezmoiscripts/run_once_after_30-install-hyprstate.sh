#!/bin/bash
# Install hyprstate from its package repository.
#   Fedora -> COPR (solaris765/hyprstate)
#   Arch   -> AUR (paru), or makepkg from packaging/ until published
# Replaces the old git-clone + ./install.sh dev install. Idempotent.
# Source: https://github.com/MasonRhodesDev/hyprstate
set -euo pipefail

COPR="solaris765/hyprstate"

echo "=== hyprstate: package install ==="

# Already installed as a package? Done.
if command -v rpm >/dev/null 2>&1 && rpm -q hyprstate >/dev/null 2>&1; then
    echo "hyprstate RPM already installed — skipping"
    exit 0
fi
if command -v pacman >/dev/null 2>&1 && pacman -Qi hyprstate >/dev/null 2>&1; then
    echo "hyprstate already installed (pacman) — skipping"
    exit 0
fi

# Tear down any prior git-symlink dev install (no-op on fresh machines). The
# packaged unit/udev/dbus files in /usr would otherwise be shadowed/duplicated
# by the dev install's /etc and /usr/local copies.
DEV_REPO="$HOME/repos/hyprstate"
if [ -e /usr/local/bin/hyprstate ] || [ -e /usr/local/libexec/hyprstate ] \
   || [ -e /usr/local/libexec/hyprstate-v2 ]; then
    if [ -x "$DEV_REPO/packaging/migrate-from-devinstall.sh" ]; then
        echo "Migrating off the git-symlink dev install..."
        "$DEV_REPO/packaging/migrate-from-devinstall.sh" || true
    else
        echo "WARN: dev install present but migrate script missing at $DEV_REPO" >&2
    fi
fi

# Distro detection.
. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
    *" fedora "*)
        echo "Fedora: enabling COPR $COPR and installing"
        sudo dnf copr enable -y "$COPR"
        sudo dnf install -y hyprstate
        ;;
    *" arch "*)
        echo "Arch: installing hyprstate from the AUR"
        if command -v paru >/dev/null 2>&1; then
            paru -S --noconfirm hyprstate
        else
            echo "ERROR: no AUR helper (paru) found. Install one, or run" >&2
            echo "       makepkg -si from the repo's packaging/ directory." >&2
            exit 1
        fi
        ;;
    *)
        echo "ERROR: unsupported distro (ID=${ID:-?}). Install hyprstate manually." >&2
        exit 1
        ;;
esac

# The RPM/AUR presets enable the units on first install; start them now so the
# live session is managed without waiting for a relog.
sudo systemctl enable --now hyprstate-powerd.service || true
systemctl --user enable --now hyprstate.service || true

echo "hyprstate installed. Logs: journalctl --user -u hyprstate.service"

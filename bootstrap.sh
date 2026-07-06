#!/bin/bash
# Fresh-machine bootstrap for Mason's dotfiles.
#
#   sh -c "$(curl -fsLS https://raw.githubusercontent.com/MasonRhodesDev/dotfiles/main/bootstrap.sh)"
#
# Installs the prerequisites chezmoi can't provide itself (git may be missing
# entirely on a fresh install), sets up rbw (Bitwarden CLI) so the identity
# prompts during `chezmoi init` get seeded with real values, then runs
# `chezmoi init --apply`. Everything is idempotent — safe to re-run.
set -euo pipefail

REPO="MasonRhodesDev/dotfiles"

say()  { printf '\n\033[1;34m== %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*"; }

# --- distro detection -------------------------------------------------------
. /etc/os-release
case "$ID" in
    arch)   PKG_INSTALL=(sudo pacman -S --needed --noconfirm) ;;
    fedora) PKG_INSTALL=(sudo dnf install -y) ;;
    *) echo "Unsupported distro: $ID (arch/fedora only)" >&2; exit 1 ;;
esac

# --- prerequisites ----------------------------------------------------------
say "Installing prerequisites (git, jq, chezmoi, rbw, pinentry)"
pkgs=(git jq chezmoi pinentry)
if [ "$ID" = "arch" ]; then
    pkgs+=(rbw)
else
    warn "rbw is not packaged for Fedora — identity prompts will need manual input"
    warn "(install later from https://github.com/doy/rbw, then run chezmoi-refresh-identity)"
fi
"${PKG_INSTALL[@]}" "${pkgs[@]}"

# --- rbw (Bitwarden) setup, so identity seeds correctly at init -------------
if command -v rbw >/dev/null; then
    if rbw unlocked >/dev/null 2>&1; then
        say "rbw already configured and unlocked"
    else
        say "Bitwarden (rbw) setup"
        current_email=$(rbw config show 2>/dev/null | jq -r '.email // empty' || true)
        if [ -z "$current_email" ]; then
            read -rp "Bitwarden email (empty to skip rbw setup): " bw_email
            if [ -z "$bw_email" ]; then
                warn "Skipping rbw — chezmoi init will prompt for identity manually"
            else
                rbw config set email "$bw_email"
                rbw register || warn "register failed (self-hosted/official mismatch is fine)"
            fi
        fi
        if rbw config show 2>/dev/null | jq -e '.email' >/dev/null 2>&1; then
            rbw login && rbw unlock && rbw sync \
                || warn "rbw not unlocked — chezmoi init will prompt for identity manually"
        fi
    fi
    if rbw unlocked >/dev/null 2>&1 && ! rbw get --field name chezmoi-data >/dev/null 2>&1; then
        warn "No 'chezmoi-data' secure note found in Bitwarden."
        warn "Create one with custom fields:"
        warn "  name, email_work, email_personal   (git identity)"
        warn "  git_overrides                       (JSON: dir/org -> identity rules)"
        warn "  work_claude_md, work_overlay_repo   (work machines only)"
        warn "(chezmoi init will fall back to prompts / safe defaults otherwise.)"
    fi
    # Use a TTY-capable pinentry so `rbw unlock` works over a console/SSH during
    # `chezmoi init` (no GUI popup needed) — the "cli pin-lock" for headless setup.
    rbw config set pinentry pinentry-curses 2>/dev/null || true
fi

# --- chezmoi init + apply ---------------------------------------------------
say "chezmoi init --apply $REPO"
# First clone uses https (no SSH key exists yet on a fresh machine); switch the
# remote to SSH later: git -C ~/.local/share/chezmoi remote set-url origin git@github.com:$REPO.git
chezmoi init --apply "https://github.com/$REPO.git"

say "Done. Log out/in (or reboot) for session services to start cleanly."

#!/bin/bash
# Virtual-console (pure TTY) UX: readable Terminus font sized to the
# framebuffer, early-boot font via initramfs, and gpm mouse copy/paste.
# Shell-side niceties (palette, tmux attach, no blanking) live in
# ~/.config/fish/conf.d/tty.fish. Cross-distro: Arch + Fedora.
# Idempotent: installs/edits only when something differs.
set -euo pipefail

. /etc/os-release 2>/dev/null || true

# --- packages -----------------------------------------------------------
need_pkgs=""
case " ${ID:-} ${ID_LIKE:-} " in
    *" arch "*)
        pacman -Qq terminus-font >/dev/null 2>&1 || need_pkgs="terminus-font"
        pacman -Qq gpm           >/dev/null 2>&1 || need_pkgs="$need_pkgs gpm"
        [ -n "${need_pkgs// }" ] && sudo pacman -S --needed --noconfirm $need_pkgs
        ;;
    *" fedora "*)
        rpm -q terminus-fonts-console >/dev/null 2>&1 || need_pkgs="terminus-fonts-console"
        rpm -q gpm                    >/dev/null 2>&1 || need_pkgs="$need_pkgs gpm"
        [ -n "${need_pkgs// }" ] && sudo dnf install -y $need_pkgs
        ;;
    *)
        echo "  unknown distro (${ID:-?}) — skipping TTY console setup"; exit 0
        ;;
esac

# --- console font sized to framebuffer height ---------------------------
# Terminus PSF caps out at 16x32; pick by vertical pixels so the same
# script lands sensibly on the 3440x1440 desktop, the FW16, or a 768p box.
fb_h=0
if [ -r /sys/class/graphics/fb0/virtual_size ]; then
    fb_h=$(cut -d, -f2 /sys/class/graphics/fb0/virtual_size)
fi
if   [ "$fb_h" -ge 1300 ]; then font=ter-132b   # 16x32
elif [ "$fb_h" -ge 900  ]; then font=ter-124b   # 12x24
elif [ "$fb_h" -ge 1    ]; then font=ter-118b   # 10x18
else                            font=ter-124b   # no fb info — middle ground
fi

vconsole_changed=0
if ! grep -qx "FONT=$font" /etc/vconsole.conf 2>/dev/null; then
    if grep -q '^FONT=' /etc/vconsole.conf 2>/dev/null; then
        sudo sed -i "s/^FONT=.*/FONT=$font/" /etc/vconsole.conf
    else
        printf 'FONT=%s\n' "$font" | sudo tee -a /etc/vconsole.conf >/dev/null
    fi
    echo "  vconsole FONT=$font (fb height ${fb_h}px)"
    vconsole_changed=1
fi

# --- early-boot font: rebuild initramfs only when the font changed -------
if [ "$vconsole_changed" = 1 ]; then
    if command -v mkinitcpio >/dev/null 2>&1; then
        if grep -Eq '^HOOKS=.*(consolefont|sd-vconsole)' /etc/mkinitcpio.conf; then
            sudo mkinitcpio -P
        else
            echo "  NOTE: no consolefont/sd-vconsole hook in mkinitcpio.conf — font applies late, not in early boot"
        fi
    elif command -v dracut >/dev/null 2>&1; then
        sudo dracut -f
    fi
    # apply to live VTs now (no-op inside a graphical session's VT)
    sudo systemctl restart systemd-vconsole-setup 2>/dev/null || true
fi

# --- gpm: mouse select/paste on the console ------------------------------
if ! systemctl is-enabled -q gpm.service 2>/dev/null; then
    sudo systemctl enable --now gpm.service
    echo "  gpm enabled"
fi

echo "✓ TTY console setup applied"

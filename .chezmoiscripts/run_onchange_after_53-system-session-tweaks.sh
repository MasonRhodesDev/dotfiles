#!/bin/bash
# Misc system /etc tweaks for the Hyprland/Wayland session: seat/input device
# access, fingerprint unlock, and Docker DNS. Each file installed idempotently;
# sudo only when content differs. Reloads only the subsystems that changed.
set -euo pipefail

install_file() { # $1=dest $2=content $3=mode
    local d="$1" m="${3:-0644}"
    if [ -f "$d" ] && [ "$(cat "$d")" = "$2" ]; then return 1; fi   # 1 = unchanged
    sudo install -d "$(dirname "$d")"
    printf '%s\n' "$2" | sudo tee "$d" >/dev/null
    sudo chmod "$m" "$d"
    echo "  installed $d"
    return 0
}

reload_udev=0; reload_systemd=0; reload_resolved=0

# ZSA keyboards (Moonlander / Ergodox EZ / Planck EZ / Voyager): hidraw + flashing
install_file /etc/udev/rules.d/50-zsa.rules \
'# Rules for Oryx web flashing and live training
KERNEL=="hidraw*", ATTRS{idVendor}=="16c0", MODE="0664", GROUP="plugdev"
KERNEL=="hidraw*", ATTRS{idVendor}=="3297", MODE="0664", GROUP="plugdev"

# Legacy rules for live training over webusb (Not needed for firmware v21+)
  # Rule for all ZSA keyboards
  SUBSYSTEM=="usb", ATTR{idVendor}=="3297", GROUP="plugdev"
  # Rule for the Moonlander
  SUBSYSTEM=="usb", ATTR{idVendor}=="3297", ATTR{idProduct}=="1969", GROUP="plugdev"
  # Rule for the Ergodox EZ
  SUBSYSTEM=="usb", ATTR{idVendor}=="feed", ATTR{idProduct}=="1307", GROUP="plugdev"
  # Rule for the Planck EZ
  SUBSYSTEM=="usb", ATTR{idVendor}=="feed", ATTR{idProduct}=="6060", GROUP="plugdev"

# Wally Flashing rules for the Ergodox EZ
ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789B]?", ENV{ID_MM_DEVICE_IGNORE}="1"
ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789A]?", ENV{MTP_NO_PROBE}="1"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789ABCD]?", MODE:="0666"
KERNEL=="ttyACM*", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789B]?", MODE:="0666"

# Keymapp / Wally Flashing rules for the Moonlander and Planck EZ
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", MODE:="0666", SYMLINK+="stm32_dfu"
# Keymapp Flashing rules for the Voyager
SUBSYSTEMS=="usb", ATTRS{idVendor}=="3297", MODE:="0666", SYMLINK+="ignition_dfu"' \
    && reload_udev=1

# hyprlock: fingerprint (pam_pcbiounlock) then password fallback. The
# `sufficient` line safely no-ops if the module is absent on a given machine.
install_file /etc/pam.d/hyprlock \
'#%PAM-1.0
auth [success=1 new_authtok_reqd=1 default=ignore] pam_unix.so try_first_pass likeauth nullok
auth sufficient pam_pcbiounlock.so
# PAM configuration file for hyprlock
auth        include     login' || true

# greetd greeter device-access groups (drop-in). NB: the greetd *config* + PAM
# live in the external /opt/greetd-config repo; this is just the unit drop-in.
install_file /etc/systemd/system/greetd.service.d/groups.conf \
'[Service]
SupplementaryGroups=seat video input render' \
    && reload_systemd=1

# seatd socket hardening
install_file /etc/systemd/system/seatd.service.d/umask.conf \
'[Service]
UMask=0007' \
    && reload_systemd=1

# Docker bridge DNS stub (only meaningful with Docker installed)
if command -v docker >/dev/null 2>&1; then
    install_file /etc/systemd/resolved.conf.d/docker.conf \
'[Resolve]
DNSStubListenerExtra=172.17.0.1' \
        && reload_resolved=1
else
    echo "  docker not present — skipping resolved docker.conf"
fi

[ "$reload_udev" = 1 ]     && { sudo udevadm control --reload && sudo udevadm trigger; echo "  udev reloaded"; }
[ "$reload_systemd" = 1 ]  && { sudo systemctl daemon-reload; echo "  systemd reloaded"; }
[ "$reload_resolved" = 1 ] && { sudo systemctl restart systemd-resolved 2>/dev/null || true; echo "  resolved restarted"; }
echo "✓ system session tweaks applied"

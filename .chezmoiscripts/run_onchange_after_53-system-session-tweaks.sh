#!/bin/bash
set -euo pipefail

install_file() {
    local d="$1" m="${3:-0644}"
    if [ -f "$d" ] && [ "$(cat "$d")" = "$2" ]; then return 1; fi
    sudo install -d "$(dirname "$d")"
    printf '%s\n' "$2" | sudo tee "$d" >/dev/null
    sudo chmod "$m" "$d"
    echo "  installed $d"
    return 0
}

reload_udev=0; reload_systemd=0; reload_resolved=0

install_file /etc/udev/rules.d/50-zsa.rules \
'KERNEL=="hidraw*", ATTRS{idVendor}=="16c0", MODE="0664", GROUP="plugdev"
KERNEL=="hidraw*", ATTRS{idVendor}=="3297", MODE="0664", GROUP="plugdev"

  SUBSYSTEM=="usb", ATTR{idVendor}=="3297", GROUP="plugdev"
  SUBSYSTEM=="usb", ATTR{idVendor}=="3297", ATTR{idProduct}=="1969", GROUP="plugdev"
  SUBSYSTEM=="usb", ATTR{idVendor}=="feed", ATTR{idProduct}=="1307", GROUP="plugdev"
  SUBSYSTEM=="usb", ATTR{idVendor}=="feed", ATTR{idProduct}=="6060", GROUP="plugdev"

ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789B]?", ENV{ID_MM_DEVICE_IGNORE}="1"
ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789A]?", ENV{MTP_NO_PROBE}="1"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789ABCD]?", MODE:="0666"
KERNEL=="ttyACM*", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789B]?", MODE:="0666"

SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", MODE:="0666", SYMLINK+="stm32_dfu"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="3297", MODE:="0666", SYMLINK+="ignition_dfu"' \
    && reload_udev=1

install_file /etc/pam.d/hyprlock \
'#%PAM-1.0
auth [success=1 new_authtok_reqd=1 default=ignore] pam_unix.so try_first_pass likeauth nullok
auth sufficient pam_pcbiounlock.so
auth        include     login' || true

install_file /etc/systemd/system/greetd.service.d/groups.conf \
'[Service]
SupplementaryGroups=seat video input render' \
    && reload_systemd=1

install_file /etc/systemd/system/seatd.service.d/umask.conf \
'[Service]
UMask=0007' \
    && reload_systemd=1

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

#!/bin/bash

set -euo pipefail

command -v nmcli >/dev/null 2>&1 || {
    echo "nmcli not present; skipping Wi-Fi powersave config"
    exit 0
}

CONF=/etc/NetworkManager/conf.d/wifi-powersave-off.conf

install_file() {
    local d="$1" m="${3:-0644}"
    if [ -f "$d" ] && [ "$(cat "$d")" = "$2" ]; then return 1; fi
    sudo install -d "$(dirname "$d")"
    printf '%s\n' "$2" | sudo tee "$d" >/dev/null
    sudo chmod "$m" "$d"
    echo "  installed $d"
    return 0
}

compat=$(tr '\0' '\n' < /sys/firmware/devicetree/base/compatible 2>/dev/null || true)
case "$compat" in
    *apple,*) apple=1 ;;
    *)        apple=0 ;;
esac

if [ "$apple" = 1 ]; then
    changed=0
    APPLE_CONF=/etc/NetworkManager/conf.d/wifi-powersave.conf
    if [ -f "$CONF" ]; then sudo rm -f "$CONF"; changed=1; fi

    if ! command -v iw >/dev/null 2>&1 && command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm iw
    fi

    read -r -d '' DESIRED <<'EOF' || true
[connection]
# Managed by chezmoi: .chezmoiscripts/run_onchange_after_50-nm-wifi-powersave.sh
wifi.powersave = 3
EOF
    install_file "$APPLE_CONF" "$DESIRED" && changed=1

    install_file /usr/local/sbin/wifi-powersave-by-ac \
'#!/bin/bash
# Managed by chezmoi: .chezmoiscripts/run_onchange_after_50-nm-wifi-powersave.sh
online=$(cat /sys/class/power_supply/macsmc-ac/online 2>/dev/null || echo 1)
if [ "$online" = 1 ]; then mode=off; else mode=on; fi
for w in /sys/class/net/*/wireless; do
    [ -d "$w" ] || continue
    dev=$(basename "$(dirname "$w")")
    if /usr/bin/iw dev "$dev" set power_save "$mode" 2>/dev/null; then
        logger -t wifi-powersave "$dev power_save $mode (ac_online=$online)"
    else
        logger -t wifi-powersave "failed to set $dev power_save $mode"
    fi
done
exit 0' 0755 && changed=1

    install_file /etc/udev/rules.d/61-wifi-powersave-by-ac.rules \
'# Managed by chezmoi: .chezmoiscripts/run_onchange_after_50-nm-wifi-powersave.sh
SUBSYSTEM=="power_supply", KERNEL=="macsmc-ac", RUN+="/usr/local/sbin/wifi-powersave-by-ac"' \
        && { sudo udevadm control --reload; changed=1; }

    install_file /etc/NetworkManager/dispatcher.d/50-wifi-powersave-by-ac \
'#!/bin/bash
# Managed by chezmoi: .chezmoiscripts/run_onchange_after_50-nm-wifi-powersave.sh
case "$2" in
    up) exec /usr/local/sbin/wifi-powersave-by-ac ;;
esac
exit 0' 0755 && changed=1

    if [ "$changed" = 1 ]; then
        sudo nmcli general reload conf || true
        sudo /usr/local/sbin/wifi-powersave-by-ac || true
        echo "✓ Wi-Fi power save now follows the AC state"
    else
        echo "Wi-Fi powersave-by-AC already current"
    fi
    exit 0
fi

read -r -d '' DESIRED <<'EOF' || true
[connection]
# Managed by chezmoi: .chezmoiscripts/run_onchange_after_50-nm-wifi-powersave.sh
wifi.powersave = 2
EOF

if [ -f "$CONF" ] && [ "$(cat "$CONF")" = "$DESIRED" ]; then
    echo "Wi-Fi powersave drop-in already current: $CONF"
    exit 0
fi

echo "Installing $CONF (disables Wi-Fi power save; sudo required)"
printf '%s\n' "$DESIRED" | sudo tee "$CONF" >/dev/null
sudo nmcli general reload conf || true
echo "✓ Wi-Fi power save disabled device-wide"

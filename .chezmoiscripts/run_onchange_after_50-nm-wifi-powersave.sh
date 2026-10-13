#!/bin/bash
# Wi-Fi 802.11 power save policy via NetworkManager.
#
# Why: the default power_save=on makes the Wi-Fi radio sleep between beacons,
# adding 30-100ms latency spikes (jitter) that wreck real-time calls (Google
# Meet / WebRTC) while leaving TCP traffic unaffected. wifi.powersave=2 turns
# it off for every Wi-Fi connection. Confirmed NOT something hyprstate/powerd
# touches (powerd's only power/control write is gated to GPU drm cards).
#
# Apple silicon laptops (mason-air, BCM4378 on brcmfmac) are the exception:
# the radio is one of the bigger battery draws, and that machine is an SSH
# client, not a call box. There NM is told to ENABLE power save (3) and a
# small toggler keeps it on while on battery and off on AC, driven by a udev
# rule on the macsmc-ac supply plus an NM dispatcher hook so a fresh
# connection inherits the current state. Hardware-gated on the devicetree,
# not the hostname: it is a property of the laptop, not the role.
#
# run_onchange_: chezmoi re-runs this whenever the content below changes.
# Idempotent + only invokes sudo when /etc actually differs.

set -euo pipefail

# No NetworkManager (headless / systemd-networkd host) -> nothing to do.
command -v nmcli >/dev/null 2>&1 || {
    echo "nmcli not present; skipping Wi-Fi powersave config"
    exit 0
}

CONF=/etc/NetworkManager/conf.d/wifi-powersave-off.conf

install_file() { # $1=dest $2=content $3=mode ; returns 1 when unchanged
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
    # ---- Apple silicon: power save follows the AC state -------------------
    changed=0

    # iw does the per-interface toggle; Arch ARM does not pull it in by default.
    if ! command -v iw >/dev/null 2>&1 && command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm iw
    fi

    read -r -d '' DESIRED <<'EOF' || true
[connection]
# Apple silicon laptop: let the radio power save; the AC-state toggler
# (/usr/local/sbin/wifi-powersave-by-ac) turns it off again while plugged in.
# Managed by chezmoi: .chezmoiscripts/run_onchange_after_50-nm-wifi-powersave.sh
wifi.powersave = 3
EOF
    install_file "$CONF" "$DESIRED" && changed=1

    install_file /usr/local/sbin/wifi-powersave-by-ac \
'#!/bin/bash
# Wi-Fi power save on battery, off on AC. Called by udev (macsmc-ac change)
# and by the NetworkManager dispatcher (interface up).
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
'# Re-evaluate Wi-Fi power save whenever the AC adapter state changes.
# Managed by chezmoi: .chezmoiscripts/run_onchange_after_50-nm-wifi-powersave.sh
SUBSYSTEM=="power_supply", KERNEL=="macsmc-ac", RUN+="/usr/local/sbin/wifi-powersave-by-ac"' \
        && { sudo udevadm control --reload; changed=1; }

    install_file /etc/NetworkManager/dispatcher.d/50-wifi-powersave-by-ac \
'#!/bin/bash
# A freshly connected interface starts with NM'"'"'s wifi.powersave setting;
# bring it in line with the current AC state.
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

# ---- Everything else: power save off, device-wide ---------------------------
read -r -d '' DESIRED <<'EOF' || true
[connection]
# Disable Wi-Fi power saving (causes jitter on real-time calls / Meet).
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

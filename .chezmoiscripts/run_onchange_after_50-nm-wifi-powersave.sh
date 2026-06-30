#!/bin/bash
# Disable Wi-Fi 802.11 power save device-wide via NetworkManager.
#
# Why: the default power_save=on makes the Wi-Fi radio sleep between beacons,
# adding 30-100ms latency spikes (jitter) that wreck real-time calls (Google
# Meet / WebRTC) while leaving TCP traffic unaffected. wifi.powersave=2 turns
# it off for every Wi-Fi connection. Confirmed NOT something hyprstate/powerd
# touches (powerd's only power/control write is gated to GPU drm cards).
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

#!/bin/bash

set -euo pipefail

CONF=/etc/bluetooth/main.conf

[ -f "$CONF" ] || {
    echo "$CONF not present; skipping bluetooth tweaks"
    exit 0
}

if grep -q '^JustWorksRepairing = always' "$CONF" &&
    grep -q '^AutoEnable=true' "$CONF"; then
    echo "Bluetooth main.conf already current"
    exit 0
fi

echo "Updating $CONF (JustWorksRepairing/AutoEnable; sudo required)"
if ! grep -q '^JustWorksRepairing' "$CONF"; then
    sudo sed -i 's|^#JustWorksRepairing = .*|JustWorksRepairing = always|' "$CONF"
fi
sudo sed -i 's|^JustWorksRepairing = .*|JustWorksRepairing = always|' "$CONF"
if ! grep -q '^AutoEnable' "$CONF"; then
    sudo sed -i 's|^#AutoEnable=.*|AutoEnable=true|' "$CONF"
fi
sudo sed -i 's|^AutoEnable=.*|AutoEnable=true|' "$CONF"

sudo systemctl try-restart bluetooth.service || true
echo "✓ Bluetooth re-pairing + auto-enable configured"

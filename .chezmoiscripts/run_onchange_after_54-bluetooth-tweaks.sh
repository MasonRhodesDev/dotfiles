#!/bin/bash
# BlueZ tweaks for Xbox controllers (and BLE gamepads generally).
#
# Why: Xbox Wireless Controllers silently drop their side of the bond when
# the pair button is held (e.g. after pairing to an Xbox/another PC). With
# the default JustWorksRepairing=never, BlueZ then refuses the re-pair and
# the controller storms connect/disconnect (observed 2026-07-13: ~80 cycles
# in 8 min, spamming Steam). "always" lets Just-Works devices re-bond
# seamlessly. AutoEnable powers the adapter at boot/daemon restart.
#
# run_onchange_: chezmoi re-runs this whenever the content below changes.
# Idempotent + only invokes sudo when /etc actually differs.

set -euo pipefail

CONF=/etc/bluetooth/main.conf

# No BlueZ on this machine -> nothing to do.
[ -f "$CONF" ] || {
    echo "$CONF not present; skipping bluetooth tweaks"
    exit 0
}

# desired: JustWorksRepairing = always, AutoEnable=true
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

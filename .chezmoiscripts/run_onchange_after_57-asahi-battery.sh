#!/bin/bash
# Apple silicon (Asahi) battery charge cap: stop charging at 80% to slow
# cell wear on a laptop that mostly lives on a desk and is rarely drained
# in one sitting. The macsmc-battery driver exposes
# charge_control_end_threshold; Asahi's packaged
# macsmc-battery-charge-control-end-threshold.path unit persists whatever is
# written there to /etc/udev/macsmc-battery.conf, and its udev rule restores
# it on every boot, so a single write is the whole mechanism.
#
# Hardware-gated: only on an Apple silicon devicetree with the attribute.
# run_onchange_: re-runs when this file changes; sudo only when the value differs.
set -euo pipefail

CAP=80
ATTR=/sys/class/power_supply/macsmc-battery/charge_control_end_threshold

compat=$(tr '\0' '\n' < /sys/firmware/devicetree/base/compatible 2>/dev/null || true)
case "$compat" in
    *apple,*) : ;;
    *) echo "Not Apple silicon, skipping battery charge cap"; exit 0 ;;
esac

[ -f "$ATTR" ] || { echo "No $ATTR, skipping battery charge cap"; exit 0; }

current=$(cat "$ATTR")
if [ "$current" = "$CAP" ]; then
    echo "Battery charge cap already $CAP%"
    exit 0
fi

echo "Setting battery charge cap $current% -> $CAP% (sudo required)"
printf '%s\n' "$CAP" | sudo tee "$ATTR" >/dev/null
echo "✓ Battery charge cap set to $CAP% (persisted by Asahi's macsmc-battery path unit)"

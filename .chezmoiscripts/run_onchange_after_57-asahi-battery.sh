#!/bin/bash
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

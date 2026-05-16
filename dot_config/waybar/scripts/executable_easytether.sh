#!/bin/bash
# Waybar module for EasyTether USB status.
# stdout: JSON for waybar (text + tooltip)
# exit 1: hides the module (exec-if behaviour)

IFACE="tap-easytether"

IP=/usr/sbin/ip
ip4=$($IP -4 -br addr show "$IFACE" 2>/dev/null | awk '{print $3}' | cut -d/ -f1)
link_up=$($IP link show "$IFACE" up 2>/dev/null)

if [ -z "$ip4" ] || [ -z "$link_up" ]; then
  exit 1
fi

printf '{"text":"󰱓","tooltip":"%s on %s","class":"active"}\n' "$ip4" "$IFACE"

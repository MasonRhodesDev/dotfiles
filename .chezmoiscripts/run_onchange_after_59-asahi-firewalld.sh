#!/bin/bash
# Firewall for the Apple silicon laptop (mason-air): firewalld with
# NetworkManager zone integration, so trust is a property of the Wi-Fi
# connection rather than the interface.
#
# Policy:
#   * default zone "public" (untrusted): inbound dropped except dhcpv6-client.
#     ssh is removed from the stock public zone, so the laptop is not
#     reachable on cafe / office Wi-Fi. Every new network lands here.
#   * trusted home networks (TRUSTED below) go in the "home" zone, which
#     keeps ssh, mdns and samba-client open. Zone is pinned on the NM
#     connection profile (connection.zone); NM owns interface-to-zone
#     mapping, so firewall-cmd --change-interface is deliberately not used.
# Outbound is never filtered, so the SSH path to dev is unaffected.
#
# Scoped to Apple silicon on purpose: the dev box must keep ssh reachable
# and is not a roaming laptop. Set up 2026-10-13.
# run_onchange_: re-runs when this file changes; idempotent, sudo only when
# something actually differs.
set -euo pipefail

TRUSTED=(MtDoom)

compat=$(tr '\0' '\n' < /sys/firmware/devicetree/base/compatible 2>/dev/null || true)
case "$compat" in
    *apple,*) : ;;
    *) echo "Not Apple silicon, skipping firewalld policy"; exit 0 ;;
esac

command -v nmcli >/dev/null 2>&1 || { echo "nmcli not present; skipping firewalld policy"; exit 0; }

if ! command -v firewall-cmd >/dev/null 2>&1; then
    if command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm firewalld
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y firewalld
    else
        echo "No known package manager; install firewalld by hand"; exit 1
    fi
fi

# firewalld must own the ruleset; the standalone units would fight it.
for u in nftables iptables; do
    if systemctl is-enabled "$u" >/dev/null 2>&1; then
        sudo systemctl disable --now "$u"
        echo "  disabled $u.service (conflicts with firewalld)"
    fi
done

if ! systemctl is-enabled firewalld >/dev/null 2>&1 || ! systemctl is-active firewalld >/dev/null 2>&1; then
    sudo systemctl enable --now firewalld
    echo "  enabled firewalld"
fi

reload=0
fc() { sudo firewall-cmd "$@"; }

if [ "$(fc --get-default-zone)" != public ]; then
    fc --set-default-zone=public; reload=1
fi

if fc --permanent --zone=public --query-service=ssh >/dev/null 2>&1; then
    fc --permanent --zone=public --remove-service=ssh; reload=1
    echo "  removed ssh from public zone"
fi

[ "$reload" = 1 ] && fc --reload

# Pin a zone on every Wi-Fi profile: home for TRUSTED, public otherwise.
changed=0
while IFS=: read -r name type; do
    [ "$type" = "802-11-wireless" ] || continue
    want=public
    for t in "${TRUSTED[@]}"; do [ "$name" = "$t" ] && want=home; done
    have=$(nmcli -g connection.zone connection show "$name" 2>/dev/null || true)
    if [ "$have" != "$want" ]; then
        sudo nmcli connection modify "$name" connection.zone "$want"
        echo "  $name -> zone $want"
        changed=1
        # re-apply if this profile is the live one so the zone takes effect now
        if nmcli -t -f NAME connection show --active | grep -qx "$name"; then
            sudo nmcli connection up "$name" >/dev/null || true
        fi
    fi
done < <(nmcli -t -f NAME,TYPE connection show)

if [ "$reload" = 1 ] || [ "$changed" = 1 ]; then
    echo "✓ firewalld policy applied"
else
    echo "firewalld policy already current"
fi

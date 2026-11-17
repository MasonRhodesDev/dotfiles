#!/bin/bash
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

changed=0
while IFS=: read -r name type; do
    [ "$type" = "802-11-wireless" ] || continue
    want=public
    for t in "${TRUSTED[@]}"; do [ "$name" = "$t" ] && want=trusted; done
    have=$(nmcli -g connection.zone connection show "$name" 2>/dev/null || true)
    if [ "$have" != "$want" ]; then
        sudo nmcli connection modify "$name" connection.zone "$want"
        echo "  $name -> zone $want"
        changed=1
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

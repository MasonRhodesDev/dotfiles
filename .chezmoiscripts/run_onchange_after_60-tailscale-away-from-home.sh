#!/bin/bash
set -euo pipefail

case "$(cat /etc/hostname 2>/dev/null)" in
    mason-air) : ;;
    *) echo "Not mason-air, skipping tailscale policy"; exit 0 ;;
esac

command -v nmcli >/dev/null 2>&1 || { echo "nmcli not present; skipping tailscale policy"; exit 0; }

changed=0

if ! command -v tailscale >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm tailscale
    echo "  installed tailscale"
    changed=1
fi
if ! command -v jq >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm jq
fi

if ! systemctl is-enabled tailscaled >/dev/null 2>&1 || ! systemctl is-active tailscaled >/dev/null 2>&1; then
    sudo systemctl enable --now tailscaled
    echo "  enabled tailscaled"
    changed=1
fi

install_file() {
    local d="$1" m="${3:-0644}"
    if [ -f "$d" ] && [ "$(cat "$d")" = "$2" ]; then return 1; fi
    sudo install -d "$(dirname "$d")"
    printf '%s\n' "$2" | sudo tee "$d" >/dev/null
    sudo chmod "$m" "$d"
    echo "  installed $d"
    return 0
}

read -r -d '' HOOK <<'EOF' || true
#!/bin/bash
# Managed by chezmoi: .chezmoiscripts/run_onchange_after_60-tailscale-away-from-home.sh
[ "$2" = up ] || exit 0
[ -n "${CONNECTION_ID:-}" ] || exit 0
case "$(nmcli -g connection.type connection show "$CONNECTION_ID" 2>/dev/null)" in
    802-11-wireless|802-3-ethernet) ;;
    *) exit 0 ;;
esac
zone=$(nmcli -g connection.zone connection show "$CONNECTION_ID" 2>/dev/null || true)
state=$(tailscale status --json 2>/dev/null | jq -r .BackendState 2>/dev/null || echo unknown)
if [ "$zone" = trusted ]; then
    if [ "$state" = Running ]; then
        tailscale down && logger -t tailscale-by-network "home network $CONNECTION_ID: tailnet down"
    fi
else
    case "$state" in
        Running) ;;
        NeedsLogin|unknown)
            logger -t tailscale-by-network "away on $CONNECTION_ID but tailscale is $state; run: sudo tailscale up --operator=mason" ;;
        *)
            tailscale up --timeout=30s && logger -t tailscale-by-network "away on $CONNECTION_ID: tailnet up" ;;
    esac
fi
exit 0
EOF
install_file /etc/NetworkManager/dispatcher.d/60-tailscale-by-network "$HOOK" 0755 && changed=1

if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active firewalld >/dev/null 2>&1; then
    if ! sudo firewall-cmd --permanent --zone=trusted --query-interface=tailscale0 >/dev/null 2>&1; then
        sudo firewall-cmd --permanent --zone=trusted --add-interface=tailscale0 >/dev/null
        sudo firewall-cmd --reload >/dev/null
        echo "  tailscale0 -> firewalld trusted zone"
        changed=1
    fi
fi

if [ "$changed" = 1 ]; then
    echo "✓ tailscale policy applied"
else
    echo "tailscale policy already current"
fi

state=$(tailscale status --json 2>/dev/null | jq -r .BackendState 2>/dev/null || echo unknown)
if [ "$state" = NeedsLogin ]; then
    echo "tailscale needs a one-time login: sudo tailscale up --operator=mason"
fi

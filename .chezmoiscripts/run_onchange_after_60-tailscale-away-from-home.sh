#!/bin/bash
# Tailscale on the roaming laptop (mason-air): the tailnet is up whenever the
# laptop is on any network other than home, and down while on home Wi-Fi,
# where the dev box is reachable on the LAN directly.
#
# Pieces:
#   * tailscaled.service enabled at boot (idle when the tailnet is down).
#   * An NM dispatcher hook fires on every connection "up" and flips the
#     tailnet: a profile whose firewalld zone is "trusted" (home, as pinned by
#     59-asahi-firewalld.sh, so the two scripts share one list of home
#     networks) gets `tailscale down`, anything else `tailscale up`. Bare
#     `tailscale up` keeps the saved prefs, so flags live in the one-time
#     login, not here.
#   * tailscale0 is a tun device NM leaves unmanaged, so firewalld is told to
#     trust it directly: the laptop stays reachable (ssh, ping) over the
#     tailnet from anywhere while cafe Wi-Fi stays in the public zone.
#
# The first login is interactive and never scripted (public repo, no auth
# keys): `sudo tailscale up --operator=mason`. Until then the hook logs
# NeedsLogin and exits.
#
# Role-gated on the hostname: wanting a VPN while roaming is a property of
# this laptop's job, not its hardware. Set up 2026-10-13.
# run_onchange_: re-runs when this file changes; idempotent, sudo only when
# something actually differs.
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

install_file() { # $1=dest $2=content $3=mode ; returns 1 when unchanged
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
# Tailnet up away from home, down on home Wi-Fi. Home means the NM profile
# sits in the firewalld "trusted" zone (pinned by 59-asahi-firewalld.sh).
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

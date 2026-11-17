#!/bin/bash
set -euo pipefail

compat=$(tr '\0' '\n' < /sys/firmware/devicetree/base/compatible 2>/dev/null || true)
case "$compat" in
    *apple,*) : ;;
    *) echo "Not Apple silicon, skipping BCM4378 sleep hook"; exit 0 ;;
esac

if ! lspci -nn 2>/dev/null | grep -qi 'BCM4378'; then
    echo "No BCM4378 adapter found, skipping"; exit 0
fi

install_file() {
    local d="$1" m="${3:-0644}"
    if [ -f "$d" ] && [ "$(cat "$d")" = "$2" ]; then return 0; fi
    sudo install -d "$(dirname "$d")"
    printf '%s\n' "$2" | sudo tee "$d" >/dev/null
    sudo chmod "$m" "$d"
    echo "  installed $d"
}

if [ -f /etc/systemd/system-sleep/brcmfmac-reload ]; then
    sudo rm -f /etc/systemd/system-sleep/brcmfmac-reload
    echo "  removed stale /etc/systemd/system-sleep/brcmfmac-reload"
fi

reset_body=$(cat <<'EOF'
#!/bin/bash
# Installed by chezmoi (run_onchange_after_56-asahi-bcm4378-sleep.sh).

modules_down="brcmfmac_wcc brcmfmac hci_bcm4377"
modules_up="brcmfmac hci_bcm4377"
reason="${2:-manual}"
log() { logger -t brcmfmac-reset "$*"; }

down() {
  lsmod | grep -q '^brcmfmac ' || return 0
  if timeout 15 modprobe -r $modules_down; then
    log "unloaded $modules_down ($reason)"
  else
    log "unload failed or timed out ($reason)"
    return 1
  fi
}

up() {
  for m in $modules_up; do
    modprobe "$m" || log "failed to load $m ($reason)"
  done
  log "loaded $modules_up ($reason)"
}

case "$1" in
  down)  down ;;
  up)    up ;;
  cycle) down || true; up ;;
  *) echo "usage: $0 <down|up|cycle> [reason]" >&2; exit 2 ;;
esac
exit 0
EOF
)
install_file /usr/local/sbin/brcmfmac-reset "$reset_body" 0755

hook_body=$(cat <<'EOF'
#!/bin/bash
# Installed by chezmoi (run_onchange_after_56-asahi-bcm4378-sleep.sh).
case "$1" in
  pre)  /usr/local/sbin/brcmfmac-reset down "before $2" ;;
  post) /usr/local/sbin/brcmfmac-reset cycle "after $2" ;;
esac
exit 0
EOF
)
install_file /usr/lib/systemd/system-sleep/brcmfmac-reload "$hook_body" 0755

watch_body=$(cat <<'EOF'
#!/bin/bash
# Installed by chezmoi (run_onchange_after_56-asahi-bcm4378-sleep.sh).

cooldown=90        # seconds after a reset before we act again
window=1800        # rate-limit window
max_per_window=4
pattern='brcmf_msgbuf_query_dcmd: Timeout on response for query command|brcmf_msgbuf_tx_ioctl: Failed to reserve space in commonring'
log() { logger -t brcmfmac-watch "$*"; }

last_reset=0
window_start=$(date +%s)
window_count=0

log "watching kernel log for brcmfmac wedge"
journalctl -k -f -n 0 -o cat | grep --line-buffered -E "$pattern" | while read -r line; do
  now=$(date +%s)
  if systemctl is-active --quiet sleep.target; then
    continue   # sleep hook owns the driver right now
  fi
  lsmod | grep -q '^brcmfmac ' || continue
  if (( now - last_reset < cooldown )); then
    continue
  fi
  if (( now - window_start > window )); then
    window_start=$now; window_count=0
  fi
  if (( window_count >= max_per_window )); then
    log "wedge seen but $max_per_window resets already in the last ${window}s; backing off"
    last_reset=$now
    continue
  fi
  log "wedge detected: $line"
  /usr/local/sbin/brcmfmac-reset cycle watchdog
  last_reset=$(date +%s)
  window_count=$((window_count + 1))
done
EOF
)
watch_changed=0
if ! [ -f /usr/local/sbin/brcmfmac-watch ] || [ "$(cat /usr/local/sbin/brcmfmac-watch)" != "$watch_body" ]; then watch_changed=1; fi
install_file /usr/local/sbin/brcmfmac-watch "$watch_body" 0755

unit_body=$(cat <<'EOF'
# Installed by chezmoi (run_onchange_after_56-asahi-bcm4378-sleep.sh).
[Unit]
Description=Reset BCM4378 Wi-Fi/Bluetooth firmware when brcmfmac wedges
After=systemd-journald.service
ConditionPathExists=/usr/local/sbin/brcmfmac-watch

[Service]
Type=simple
ExecStart=/usr/local/sbin/brcmfmac-watch
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
)
unit=/etc/systemd/system/brcmfmac-watch.service
unit_changed=0
if ! [ -f "$unit" ] || [ "$(cat "$unit")" != "$unit_body" ]; then unit_changed=1; fi
install_file "$unit" "$unit_body" 0644
if [ "$unit_changed" = 1 ] || [ "$watch_changed" = 1 ]; then
    sudo systemctl daemon-reload
    sudo systemctl enable brcmfmac-watch.service >/dev/null 2>&1
    sudo systemctl restart brcmfmac-watch.service
    echo "  (re)started brcmfmac-watch.service"
elif ! systemctl is-active --quiet brcmfmac-watch.service; then
    sudo systemctl enable brcmfmac-watch.service >/dev/null 2>&1
    sudo systemctl start brcmfmac-watch.service
    echo "  started brcmfmac-watch.service"
fi

nm_body=$(cat <<'EOF'
# Installed by chezmoi (run_onchange_after_56-asahi-bcm4378-sleep.sh).
[device]
wifi.scan-rand-mac-address=no

[connection]
wifi.cloned-mac-address=permanent
EOF
)
nm_conf=/etc/NetworkManager/conf.d/brcmfmac-permanent-mac.conf
nm_changed=0
if ! [ -f "$nm_conf" ] || [ "$(cat "$nm_conf")" != "$nm_body" ]; then nm_changed=1; fi
install_file "$nm_conf" "$nm_body" 0644
if [ "$nm_changed" = 1 ] && command -v nmcli >/dev/null 2>&1; then
    sudo nmcli general reload conf && echo "  reloaded NetworkManager config"
fi

echo "BCM4378 sleep hook, watchdog and MAC policy in place"

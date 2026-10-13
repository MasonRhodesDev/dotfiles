#!/bin/bash
# Apple silicon BCM4378 (brcmfmac) Wi-Fi/Bluetooth firmware goes silent: every
# ioctl then times out ("Timeout on response for query command"), the command
# ring fills ("Failed to reserve space in commonring"), hci_bcm4377 dies with
# it, and NetworkManager cannot bring anything back. Observed 2026-10-13 on
# mason-air (MacBook Air M1, kernel 7.1.13 ARCH): after s2idle resume, and
# also 30 s after a cold-boot firmware load with no sleep involved. Only a
# fresh firmware load recovers; there is no upstream fix (AsahiLinux/linux
# issue 491, t2linux/kernel issue 32 show the same signature).
#
# Three pieces, all reboot-free:
#   1. /usr/local/sbin/brcmfmac-reset  unloads and reloads the drivers.
#   2. A system-sleep hook calls it around every suspend, so the chip never
#      has to survive sleep in place.
#   3. brcmfmac-watch.service follows the kernel log and calls it as soon as
#      the wedge signature appears, rate-limited, so a wedge at any other
#      time self-heals in a few seconds instead of needing a reboot.
# Plus NetworkManager is told to stop randomising the MAC: brcmfmac lacks
# POWERED_ADDR_CHANGE, so every scan-time MAC change is an ioctl that fails.
#
# Hardware-gated: only on an Apple silicon devicetree with a BCM4378.
# run_onchange_: re-runs when this file changes; sudo only when /etc differs.
set -euo pipefail

compat=$(tr '\0' '\n' < /sys/firmware/devicetree/base/compatible 2>/dev/null || true)
case "$compat" in
    *apple,*) : ;;
    *) echo "Not Apple silicon, skipping BCM4378 sleep hook"; exit 0 ;;
esac

if ! lspci -nn 2>/dev/null | grep -qi 'BCM4378'; then
    echo "No BCM4378 adapter found, skipping"; exit 0
fi

changed=0
install_file() { # $1=dest $2=content $3=mode
    local d="$1" m="${3:-0644}"
    if [ -f "$d" ] && [ "$(cat "$d")" = "$2" ]; then return 0; fi
    sudo install -d "$(dirname "$d")"
    printf '%s\n' "$2" | sudo tee "$d" >/dev/null
    sudo chmod "$m" "$d"
    echo "  installed $d"
    changed=1
}

# systemd 262 runs hooks from /usr/lib/systemd/system-sleep/ only: the hook
# first shipped under /etc/systemd/system-sleep/ and never fired (observed
# 2026-10-13, F6 suspend wedged the firmware with the driver still loaded).
if [ -f /etc/systemd/system-sleep/brcmfmac-reload ]; then
    sudo rm -f /etc/systemd/system-sleep/brcmfmac-reload
    echo "  removed stale /etc/systemd/system-sleep/brcmfmac-reload"
fi

# 1. Shared reset: the only thing that revives the firmware.
reset_body=$(cat <<'EOF'
#!/bin/bash
# Installed by chezmoi (run_onchange_after_56-asahi-bcm4378-sleep.sh).
# Unload and reload the BCM4378 Wi-Fi and Bluetooth drivers so the chip gets
# a fresh firmware download. Usage: brcmfmac-reset <down|up|cycle> [reason]
# NetworkManager sees a new interface and reconnects on its own; Bluetooth
# connections drop and re-pair automatically.

modules_down="brcmfmac_wcc brcmfmac hci_bcm4377"
modules_up="brcmfmac hci_bcm4377"
reason="${2:-manual}"
log() { logger -t brcmfmac-reset "$*"; }

down() {
  lsmod | grep -q '^brcmfmac ' || return 0
  # bounded, so a wedged chip cannot stop the machine from sleeping
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

# 2. Sleep hook. systemd-suspend.service runs it as root: <pre|post> <type>.
hook_body=$(cat <<'EOF'
#!/bin/bash
# Installed by chezmoi (run_onchange_after_56-asahi-bcm4378-sleep.sh).
# The BCM4378 firmware does not reliably survive s2idle, so drop the drivers
# before sleep and load them fresh after resume via brcmfmac-reset.
case "$1" in
  pre)  /usr/local/sbin/brcmfmac-reset down "before $2" ;;
  post) /usr/local/sbin/brcmfmac-reset cycle "after $2" ;;
esac
exit 0
EOF
)
install_file /usr/lib/systemd/system-sleep/brcmfmac-reload "$hook_body" 0755

# 3. Watchdog: first timeout means the command ring is dead (never recovers
# on its own), so reset on the first match. Guards: never while
# systemd-suspend.service is running (the sleep hook's own unload logs a
# timeout), a cooldown after our own reset (fresh firmware can wedge again
# 30 s after load), and a cap per window so a chip that will not come back
# does not get reset in a tight loop.
watch_body=$(cat <<'EOF'
#!/bin/bash
# Installed by chezmoi (run_onchange_after_56-asahi-bcm4378-sleep.sh).
# Follow the kernel log for the brcmfmac wedge signature and reset the
# drivers via brcmfmac-reset. Runs as brcmfmac-watch.service.

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
  if systemctl is-active --quiet systemd-suspend.service; then
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
if [ "$unit_changed" = 1 ]; then
    sudo systemctl daemon-reload
    sudo systemctl enable brcmfmac-watch.service >/dev/null 2>&1
    sudo systemctl restart brcmfmac-watch.service
    echo "  (re)started brcmfmac-watch.service"
elif ! systemctl is-active --quiet brcmfmac-watch.service; then
    sudo systemctl enable brcmfmac-watch.service >/dev/null 2>&1
    sudo systemctl start brcmfmac-watch.service
    echo "  started brcmfmac-watch.service"
fi

# 4. brcmfmac cannot change MAC on a live interface (no POWERED_ADDR_CHANGE),
# so NetworkManager's per-scan random MAC is a failing ioctl on every wake.
nm_body=$(cat <<'EOF'
# Installed by chezmoi (run_onchange_after_56-asahi-bcm4378-sleep.sh).
# brcmfmac on Apple silicon cannot change the MAC of a live interface, so
# keep the permanent address instead of randomising per scan/connection.
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

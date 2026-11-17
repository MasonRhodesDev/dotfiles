#!/bin/bash
set -euo pipefail

vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)
product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
case "$vendor:$product" in
    Framework:*Laptop\ 16*) : ;;
    *) echo "Not a Framework Laptop 16 — skipping MT7922 Wi-Fi workarounds"; exit 0 ;;
esac

kver=$(uname -r)
case "$kver" in
    6.18.*) echo "Kernel $kver in affected 6.18.x series — installing MT7922 workarounds" ;;
    *) echo "Kernel $kver not in affected 6.18.x series — MT7922 workarounds inert, skipping"; exit 0 ;;
esac

if ! lspci -nn 2>/dev/null | grep -qiE 'MEDIATEK.*MT792[12]'; then
    echo "No MT792x adapter found — skipping"; exit 0
fi

install_file() {
    local d="$1" m="${3:-0644}"
    if [ -f "$d" ] && [ "$(cat "$d")" = "$2" ]; then return 0; fi
    sudo install -d "$(dirname "$d")"
    printf '%s\n' "$2" | sudo tee "$d" >/dev/null
    sudo chmod "$m" "$d"
    echo "  installed $d"
}

install_file /etc/modprobe.d/mt7921e-workaround.conf \
'options mt7921e disable_aspm=1
options mt7921e wed_enable=0'

install_file /etc/systemd/system/wifi-resume.service \
'[Unit]
Description=Reload WiFi driver on resume from sleep
After=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/modprobe -r mt7921e
ExecStart=/bin/sleep 2
ExecStart=/usr/sbin/modprobe mt7921e

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target'

install_file /usr/local/bin/check-wifi-health.sh \
'#!/bin/bash
LOG_FILE="/var/log/wifi-health.log"
WIFI_INTERFACE="wlp4s0"
log(){ echo "[$(date "+%F %T")] $1" | tee -a "$LOG_FILE"; }
sleep 15
if ! lsmod | grep -q "^mt7921e"; then log "ERROR: mt7921e module not loaded"; exit 1; fi
if ! ip link show "$WIFI_INTERFACE" &>/dev/null; then log "ERROR: $WIFI_INTERFACE not found"; exit 1; fi
if ! ip link show "$WIFI_INTERFACE" | grep -q "state UP\|state UNKNOWN"; then
    log "WARNING: $WIFI_INTERFACE is DOWN; bringing up"
    sudo ip link set "$WIFI_INTERFACE" up; sleep 5
fi
if ! lspci -k | grep -A3 -iE "MT792[12]" | grep -q "Kernel driver in use: mt7921e"; then
    log "ERROR: MT792x not bound to mt7921e"
    running=$(uname -r)
    fallback=$(ls -1 /boot/vmlinuz-* 2>/dev/null | sed "s|.*/vmlinuz-||" | grep -v "^$running$" | sort -V | tail -1)
    if [ -n "$fallback" ]; then
        log "Setting one-shot fallback boot: $fallback"
        entry=$(grep -n "menuentry.*$fallback" /boot/grub2/grub.cfg 2>/dev/null | head -1 | cut -d: -f1)
        [ -n "$entry" ] && sudo grub2-set-default "$entry"
    else
        log "No alternate kernel available for fallback"
    fi
    exit 1
fi
log "SUCCESS: WiFi hardware and driver operational"
exit 0' 0755

install_file /etc/systemd/system/wifi-health-check.service \
'[Unit]
Description=MT7921/MT7922 WiFi Driver Health Check
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/check-wifi-health.sh
StandardOutput=journal
StandardError=journal
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target'

sudo systemctl daemon-reload
sudo systemctl enable wifi-resume.service wifi-health-check.service || true
echo "✓ MT7922 Wi-Fi workarounds installed for kernel $kver"

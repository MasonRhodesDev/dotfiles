#!/bin/bash
# Apple silicon BCM4378 (brcmfmac) Wi-Fi/Bluetooth survives s2idle badly: the
# firmware stops draining brcmfmac's command ring, every ioctl after resume
# fails with -12 ("Failed to reserve space in commonring"), hci_bcm4377 times
# out alongside it, and NetworkManager cannot bring anything back. Only a
# fresh firmware load recovers, which used to mean a reboot.
#
# Fix: a system-sleep hook that unloads the drivers before suspend and loads
# them again after resume, so the chip never has to survive sleep at all.
# Observed 2026-10-13 on mason-air (MacBook Air M1, kernel 7.1.x ARCH).
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

install_file() { # $1=dest $2=content $3=mode
    local d="$1" m="${3:-0644}"
    if [ -f "$d" ] && [ "$(cat "$d")" = "$2" ]; then return 0; fi
    sudo install -d "$(dirname "$d")"
    printf '%s\n' "$2" | sudo tee "$d" >/dev/null
    sudo chmod "$m" "$d"
    echo "  installed $d"
}

# systemd 262 runs hooks from /usr/lib/systemd/system-sleep/ only: the hook
# first shipped under /etc/systemd/system-sleep/ and never fired (observed
# 2026-10-13, F6 suspend wedged the firmware with the driver still loaded).
if [ -f /etc/systemd/system-sleep/brcmfmac-reload ]; then
    sudo rm -f /etc/systemd/system-sleep/brcmfmac-reload
    echo "  removed stale /etc/systemd/system-sleep/brcmfmac-reload"
fi

install_file /usr/lib/systemd/system-sleep/brcmfmac-reload \
'#!/bin/bash
# Installed by chezmoi (run_onchange_after_56-asahi-bcm4378-sleep.sh).
# Unload the BCM4378 Wi-Fi and Bluetooth drivers before sleep and load them
# again after resume; the firmware does not reliably survive s2idle.
# systemd-suspend.service runs this as root with <pre|post> <sleep-type>.

modules_down="brcmfmac_wcc brcmfmac hci_bcm4377"
modules_up="brcmfmac hci_bcm4377"
log() { logger -t brcmfmac-reload "$*"; }

case "$1" in
  pre)
    # bounded, so a wedged chip cannot stop the machine from sleeping
    if timeout 15 modprobe -r $modules_down; then
      log "unloaded $modules_down before $2"
    else
      log "unload before $2 failed or timed out; retrying after resume"
    fi
    ;;
  post)
    if lsmod | grep -q "^brcmfmac "; then
      timeout 15 modprobe -r $modules_down || log "unload after resume failed"
    fi
    for m in $modules_up; do
      modprobe "$m" || log "failed to load $m after resume"
    done
    log "loaded $modules_up after $2"
    ;;
esac
exit 0' 0755

echo "BCM4378 sleep hook in place"

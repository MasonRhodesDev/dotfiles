#!/bin/bash
set -euo pipefail

compat=$(tr '\0' '\n' < /sys/firmware/devicetree/base/compatible 2>/dev/null || true)
case "$compat" in
    *apple,*) : ;;
    *) echo "Not Apple silicon, skipping fn key setup"; exit 0 ;;
esac

install_file() {
    local d="$1" m="${3:-0644}"
    if [ -f "$d" ] && [ "$(cat "$d")" = "$2" ]; then return 1; fi
    sudo install -d "$(dirname "$d")"
    printf '%s\n' "$2" | sudo tee "$d" >/dev/null
    sudo chmod "$m" "$d"
    echo "  installed $d"
    return 0
}

install_file /etc/modprobe.d/hid_apple.conf \
'# Managed by chezmoi: .chezmoiscripts/run_onchange_after_58-asahi-fnkeys.sh
options hid_apple fnmode=1' || true

if [ -w /sys/module/hid_apple/parameters/fnmode ] || [ -f /sys/module/hid_apple/parameters/fnmode ]; then
    if [ "$(cat /sys/module/hid_apple/parameters/fnmode)" != 1 ]; then
        echo 1 | sudo tee /sys/module/hid_apple/parameters/fnmode >/dev/null
        echo "  hid_apple fnmode set to 1 (live)"
    fi
fi

install_file /etc/systemd/logind.conf.d/50-apple-fn-row.conf \
'# Managed by chezmoi: .chezmoiscripts/run_onchange_after_58-asahi-fnkeys.sh
[Login]
HandleSuspendKey=ignore
HandleSuspendKeyLongPress=ignore' \
    && { sudo systemctl reload systemd-logind 2>/dev/null \
         || echo "  logind drop-in takes effect at next boot (reload unsupported)"; }

echo "Apple fn row configured"

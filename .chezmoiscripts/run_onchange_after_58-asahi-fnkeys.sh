#!/bin/bash
# Apple internal keyboard fn row on Asahi.
#
# hid_apple's default fnmode=3 ("auto") leaves the M1 Air's SPI keyboard
# sending plain F1..F12, so the printed brightness/media/volume legends do
# nothing. fnmode=1 (fkeyslast) is the macOS behaviour: the legend is the
# key, Fn+key is the F-key. Verified 2026-10-13 on mason-air (j313).
#
# F6 carries a moon (Do Not Disturb) legend but hid_apple reports it as
# KEY_SLEEP, which systemd-logind treats as the suspend key and suspends the
# machine. logind is told to ignore it here so the compositor can bind
# XF86Sleep to DND instead (see dot_config/hypr/local.lua.tmpl).
#
# Hardware-gated: Apple silicon devicetree with a hid_apple-bound keyboard.
# run_onchange_: re-runs when this file changes; sudo only when /etc differs.
set -euo pipefail

compat=$(tr '\0' '\n' < /sys/firmware/devicetree/base/compatible 2>/dev/null || true)
case "$compat" in
    *apple,*) : ;;
    *) echo "Not Apple silicon, skipping fn key setup"; exit 0 ;;
esac

install_file() { # $1=dest $2=content $3=mode ; returns 1 when unchanged
    local d="$1" m="${3:-0644}"
    if [ -f "$d" ] && [ "$(cat "$d")" = "$2" ]; then return 1; fi
    sudo install -d "$(dirname "$d")"
    printf '%s\n' "$2" | sudo tee "$d" >/dev/null
    sudo chmod "$m" "$d"
    echo "  installed $d"
    return 0
}

install_file /etc/modprobe.d/hid_apple.conf \
'# Apple internal keyboard: media legends are the keys, Fn+key is the F-key.
# Managed by chezmoi: .chezmoiscripts/run_onchange_after_58-asahi-fnkeys.sh
options hid_apple fnmode=1' || true

# hid_apple is built in or already loaded; apply the mode to the live kernel too.
if [ -w /sys/module/hid_apple/parameters/fnmode ] || [ -f /sys/module/hid_apple/parameters/fnmode ]; then
    if [ "$(cat /sys/module/hid_apple/parameters/fnmode)" != 1 ]; then
        echo 1 | sudo tee /sys/module/hid_apple/parameters/fnmode >/dev/null
        echo "  hid_apple fnmode set to 1 (live)"
    fi
fi

install_file /etc/systemd/logind.conf.d/50-apple-fn-row.conf \
'# F6 on the Apple internal keyboard is KEY_SLEEP; leave it to the compositor
# (bound to Do Not Disturb) instead of suspending on every press.
# Managed by chezmoi: .chezmoiscripts/run_onchange_after_58-asahi-fnkeys.sh
[Login]
HandleSuspendKey=ignore
HandleSuspendKeyLongPress=ignore' \
    && { sudo systemctl reload systemd-logind 2>/dev/null \
         || echo "  logind drop-in takes effect at next boot (reload unsupported)"; }

echo "Apple fn row configured"

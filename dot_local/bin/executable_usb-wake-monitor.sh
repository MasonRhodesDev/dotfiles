#!/bin/bash
# USB Wake Configuration Monitor
# Periodically checks USB wake settings and logs status

LOG_FILE="$HOME/.local/state/usb-wake-monitor.log"
mkdir -p "$(dirname "$LOG_FILE")"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

check_wake_status() {
    local device_path="$1"
    local device_name="$2"

    if [ -f "$device_path" ]; then
        local status=$(cat "$device_path" 2>/dev/null)
        if [ "$status" = "enabled" ]; then
            log_message "✓ $device_name: enabled"
            return 0
        else
            log_message "✗ $device_name: $status (should be enabled)"
            return 1
        fi
    else
        log_message "⚠ $device_name: not found"
        return 2
    fi
}

# Main monitoring loop
log_message "=== USB Wake Monitor Check ==="

ISSUES=0

# Check USB controller
check_wake_status "/sys/bus/pci/devices/0000:0e:00.3/power/wakeup" "USB Controller (XHC0)" || ISSUES=$((ISSUES + 1))

# Check root hubs
ROOT_HUB_COUNT=0
ROOT_HUB_DISABLED=0
for root_hub in /sys/bus/usb/devices/usb*/power/wakeup; do
    if [ -f "$root_hub" ]; then
        ROOT_HUB_COUNT=$((ROOT_HUB_COUNT + 1))
        status=$(cat "$root_hub" 2>/dev/null)
        if [ "$status" != "enabled" ]; then
            ROOT_HUB_DISABLED=$((ROOT_HUB_DISABLED + 1))
            log_message "✗ Root hub $(basename $(dirname $(dirname "$root_hub"))): $status"
            ISSUES=$((ISSUES + 1))
        fi
    fi
done

if [ $ROOT_HUB_DISABLED -eq 0 ]; then
    log_message "✓ All $ROOT_HUB_COUNT root hubs: enabled"
fi

# Check intermediate hubs
HUB_COUNT=0
HUB_DISABLED=0
for hub in /sys/bus/usb/devices/*/product; do
    if grep -q "Hub" "$hub" 2>/dev/null; then
        hub_wake="${hub%/product}/power/wakeup"
        if [ -f "$hub_wake" ]; then
            HUB_COUNT=$((HUB_COUNT + 1))
            status=$(cat "$hub_wake" 2>/dev/null)
            if [ "$status" != "enabled" ]; then
                HUB_DISABLED=$((HUB_DISABLED + 1))
                hub_name=$(cat "$hub" 2>/dev/null)
                hub_device=$(basename $(dirname "$hub"))
                log_message "✗ Hub $hub_device ($hub_name): $status"
                ISSUES=$((ISSUES + 1))
            fi
        fi
    fi
done

if [ $HUB_DISABLED -eq 0 ] && [ $HUB_COUNT -gt 0 ]; then
    log_message "✓ All $HUB_COUNT intermediate hubs: enabled"
fi

# Check keyboard (ZSA Voyager)
KEYBOARD_FOUND=false
for device in /sys/bus/usb/devices/*/idVendor; do
    if [ "$(cat "$device" 2>/dev/null)" = "3297" ]; then
        device_dir=$(dirname "$device")
        if [ "$(cat "$device_dir/idProduct" 2>/dev/null)" = "1977" ]; then
            KEYBOARD_FOUND=true
            check_wake_status "$device_dir/power/wakeup" "Keyboard (ZSA Voyager)" || ISSUES=$((ISSUES + 1))
        fi
    fi
done

if ! $KEYBOARD_FOUND; then
    log_message "⚠ Keyboard (ZSA Voyager) not connected"
fi

# Check mouse (Logitech Lightspeed)
MOUSE_FOUND=false
for device in /sys/bus/usb/devices/*/idVendor; do
    if [ "$(cat "$device" 2>/dev/null)" = "046d" ]; then
        device_dir=$(dirname "$device")
        if [ "$(cat "$device_dir/idProduct" 2>/dev/null)" = "c539" ]; then
            MOUSE_FOUND=true
            check_wake_status "$device_dir/power/wakeup" "Mouse (Logitech Lightspeed)" || ISSUES=$((ISSUES + 1))
        fi
    fi
done

if ! $MOUSE_FOUND; then
    log_message "⚠ Mouse (Logitech Lightspeed) not connected"
fi

# Summary
if [ $ISSUES -eq 0 ]; then
    log_message "=== Status: All USB wake settings are correct ==="
else
    log_message "=== Status: $ISSUES issue(s) detected ==="
    log_message "NOTE: This monitor does not auto-fix issues (requires sudo)"
    log_message "To manually fix, run: ~/.local/share/chezmoi/run_once_before_configure-usb-wake.sh.tmpl"
fi

exit 0

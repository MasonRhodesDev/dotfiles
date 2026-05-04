#!/usr/bin/env bash
# Notification history viewer for mako (1.10 — text-only IPC).
#
# Mako's history is a read-only audit log of dismissed notifications. We show
# it in wofi for reference, with two action entries at the top:
#   - Restore last  → makoctl restore (re-pop the most recent)
#   - Clear visible → dismiss currently-visible popups
# Selecting any individual entry just runs `makoctl restore` (mako 1.10 can
# only restore the most-recent dismissed; per-entry restore lands in a future
# mako release).
set -euo pipefail

history_text=$(makoctl history 2>/dev/null || true)

if [ -z "$history_text" ]; then
    notify-send -t 1500 -a notifications "No notification history"
    exit 0
fi

# Format each `Notification N: summary` plus its `App name:` line into one
# `[app] summary` row for the picker.
formatted=$(awk '
    /^Notification [0-9]+:/ { sub(/^Notification [0-9]+: */, ""); summary = $0; next }
    /^  App name: / { sub(/^  App name: /, ""); printf "[%s] %s\n", $0, summary }
' <<< "$history_text")

menu=$({
    printf 'Restore last\n'
    printf 'Clear visible\n'
    printf -- '---\n'
    echo "$formatted"
})

pick=$(echo "$menu" | wofi --dmenu --prompt "notifications" --insensitive)
[ -z "$pick" ] && exit 0

case "$pick" in
    "Restore last") makoctl restore ;;
    "Clear visible") makoctl dismiss --all ;;
    "---") ;;
    *) makoctl restore ;;
esac

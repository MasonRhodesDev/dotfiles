#!/usr/bin/env bash
# swaync-focus-sender
#
# Generic notification-click focus proxy for Hyprland.
#
# Invoked by swaync via scripts.run-on = "action" — i.e. whenever the user
# clicks a notification body (which also fires the XDG default action back to
# the originating app, so the app still routes to the right conversation /
# thread / issue / etc).
#
# Apps on Wayland can't reliably raise their own windows — especially when
# they're parked on a Hyprland special workspace (scratchpad). So we piggy-
# back: map the notification's sender identity to a Hyprland client and
# bring it to focus.
#
# swaync sets these env vars for scripts:
#   SWAYNC_APP_NAME       — "Slack", "discord", "Thunderbird", ...
#   SWAYNC_DESKTOP_ENTRY  — the .desktop basename, when the sender sets the
#                           "desktop-entry" hint (more reliable than app name)
#   SWAYNC_SUMMARY, SWAYNC_BODY, SWAYNC_URGENCY, SWAYNC_CATEGORY, SWAYNC_ID

set -u

needle_raw="${SWAYNC_DESKTOP_ENTRY:-${SWAYNC_APP_NAME:-}}"
[ -z "$needle_raw" ] && exit 0

# Lowercase, strip whitespace, strip common suffixes (" Desktop", ".desktop").
needle=$(printf '%s' "$needle_raw" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/\.desktop$//; s/[[:space:]]+desktop$//; s/^[[:space:]]+|[[:space:]]+$//g')

[ -z "$needle" ] && exit 0

# Case-insensitive substring match against each client's class / initialClass /
# initialTitle. Return address + workspace.name so we can handle special
# (scratchpad) workspaces correctly.
read -r address workspace < <(
    hyprctl clients -j 2>/dev/null | jq -r --arg n "$needle" '
        [ .[] | select(
              (.class        // "" | ascii_downcase | contains($n)) or
              (.initialClass // "" | ascii_downcase | contains($n)) or
              (.initialTitle // "" | ascii_downcase | contains($n))
        ) ] | .[0] | if . then "\(.address) \(.workspace.name)" else "" end
    '
)

[ -z "${address:-}" ] && exit 0

# Special workspaces (scratchpads) are named "special:<name>". focuswindow
# doesn't pull a window out of them, so explicitly show the special workspace
# on the current monitor first.
if [[ "$workspace" == special:* ]]; then
    special_name="${workspace#special:}"
    active_special=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .specialWorkspace.name')
    if [ "$active_special" != "$workspace" ]; then
        hyprctl dispatch togglespecialworkspace "$special_name" >/dev/null
    fi
fi

hyprctl dispatch focuswindow "address:$address" >/dev/null

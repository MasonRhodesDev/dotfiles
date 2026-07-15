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
# Apps on Wayland can't reliably raise their own windows — Electron only
# forwards the notification activation token from Electron 42 on
# (electron/electron#50568), and older apps park on Hyprland special
# workspaces (scratchpads) they can't summon. So we piggyback: map the
# notification's sender identity to a Hyprland client and bring it to focus.
#
# Per-app recovery plugins live in apps/<name>.sh (name = lowercased
# desktop-entry or app-name, full and last-dot-segment are tried, so both
# "slack" and flatpak ids like com.discordapp.Discord → "discord" resolve).
# A plugin's `on_action` runs in the background with the notification's
# stored context (see store-context.sh) and can e.g. re-issue the navigation
# as a deep link when the sender has already forgotten the notification.
#
# swaync sets these env vars for scripts:
#   SWAYNC_APP_NAME       — "Slack", "discord", "Thunderbird", ...
#   SWAYNC_DESKTOP_ENTRY  — the .desktop basename, when the sender sets the
#                           "desktop-entry" hint (more reliable than app name)
#   SWAYNC_ID, SWAYNC_TIME (epoch s), SWAYNC_SUMMARY, SWAYNC_BODY, ...

set -u

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
APPS_DIR="$SCRIPT_DIR/apps"
CTX_DIR="${XDG_RUNTIME_DIR:-/tmp}/swaync-context"

needle_raw="${SWAYNC_DESKTOP_ENTRY:-${SWAYNC_APP_NAME:-}}"
[ -z "$needle_raw" ] && exit 0

# Lowercase, strip whitespace, strip common suffixes (" Desktop", ".desktop").
needle=$(printf '%s' "$needle_raw" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/\.desktop$//; s/[[:space:]]+desktop$//; s/^[[:space:]]+|[[:space:]]+$//g')

[ -z "$needle" ] && exit 0

# --- per-app recovery plugin (background; focusing below stays instant) ----
run_plugin() {
    local name plugin
    for name in "$needle" "${needle##*.}"; do
        plugin="$APPS_DIR/$name.sh"
        if [ -f "$plugin" ]; then
            # shellcheck source=/dev/null
            . "$plugin"
            if declare -f on_action > /dev/null; then
                local ctx="$CTX_DIR/${SWAYNC_ID:-none}.env"
                if [ -f "$ctx" ]; then
                    # shellcheck source=/dev/null
                    . "$ctx"
                fi
                on_action "$ctx"
            fi
            return
        fi
    done
}
run_plugin &

# --- generic: focus the sender's window ------------------------------------
# Case-insensitive substring match against each client's class / initialClass /
# initialTitle, trying the full needle then its last dot-segment (so flatpak
# ids like com.discordapp.discord still match a window class of "discord").
# Return address + workspace.name so we can handle special (scratchpad)
# workspaces correctly.
clients_json=$(hyprctl clients -j 2>/dev/null)
address="" workspace=""
for n in "$needle" "${needle##*.}"; do
    read -r address workspace < <(
        jq -r --arg n "$n" '
            [ .[] | select(
                  (.class        // "" | ascii_downcase | contains($n)) or
                  (.initialClass // "" | ascii_downcase | contains($n)) or
                  (.initialTitle // "" | ascii_downcase | contains($n))
            ) ] | .[0] | if . then "\(.address) \(.workspace.name)" else "" end
        ' <<< "$clients_json"
    )
    [ -n "${address:-}" ] && break
done

if [ -n "${address:-}" ]; then
    # Special workspaces (scratchpads) are named "special:<name>". focuswindow
    # doesn't pull a window out of them, so explicitly show the special
    # workspace on the current monitor first.
    # Dispatch syntax depends on the active config dialect: with hyprland.lua
    # present, `hyprctl dispatch` args are Lua expressions and classic string
    # dispatchers fail (silently for keyword, loudly for dispatch).
    if [ -f "$HOME/.config/hypr/hyprland.lua" ]; then
        dispatch_toggle_special() { hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$1\")" >/dev/null; }
        dispatch_focus_window()   { hyprctl dispatch "hl.dsp.focus({ window = \"address:$1\" })" >/dev/null; }
    else
        dispatch_toggle_special() { hyprctl dispatch togglespecialworkspace "$1" >/dev/null; }
        dispatch_focus_window()   { hyprctl dispatch focuswindow "address:$1" >/dev/null; }
    fi

    if [[ "$workspace" == special:* ]]; then
        special_name="${workspace#special:}"
        active_special=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .specialWorkspace.name')
        if [ "$active_special" != "$workspace" ]; then
            dispatch_toggle_special "$special_name"
        fi
    fi

    dispatch_focus_window "$address"
fi

wait

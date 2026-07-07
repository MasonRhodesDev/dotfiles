#!/usr/bin/env bash
# swaync-store-context
#
# run-on: "receive" hook — archives every notification's metadata the moment
# it arrives, keyed by swaync notification id, so that action-time hooks
# (focus-sender.sh) still have full context long after the sender has
# forgotten about the notification (e.g. Electron apps whose GC'd
# Notification objects silently drop clicks — see apps/slack.sh).
#
# Per-app plugins in apps/<name>.sh can define an `enrich` function that
# emits extra KEY=VALUE lines (e.g. a deep link reconstructed from the app's
# own logs) to store alongside the generic fields.

set -u

CTX_DIR="${XDG_RUNTIME_DIR:-/tmp}/swaync-context"
APPS_DIR="$(dirname "$(readlink -f "$0")")/apps"

[ -n "${SWAYNC_ID:-}" ] || exit 0
mkdir -p "$CTX_DIR"

# Normalized handler-name candidates from the sender identity, most
# specific first. Handles flatpak reverse-DNS ids (com.discordapp.Discord →
# discord) as well as plain names (Slack → slack).
candidates() {
    local raw
    for raw in "${SWAYNC_DESKTOP_ENTRY:-}" "${SWAYNC_APP_NAME:-}"; do
        [ -z "$raw" ] && continue
        local lower=${raw,,}
        lower=${lower%.desktop}
        printf '%s\n' "$lower" "${lower##*.}"
    done | awk '!seen[$0]++'
}

ctx_file="$CTX_DIR/$SWAYNC_ID.env"
{
    printf '%s=%q\n' \
        APP_NAME "${SWAYNC_APP_NAME:-}" \
        DESKTOP_ENTRY "${SWAYNC_DESKTOP_ENTRY:-}" \
        SUMMARY "${SWAYNC_SUMMARY:-}" \
        TIME "${SWAYNC_TIME:-}" \
        URGENCY "${SWAYNC_URGENCY:-}"

    while IFS= read -r name; do
        plugin="$APPS_DIR/$name.sh"
        if [ -f "$plugin" ]; then
            # shellcheck source=/dev/null
            . "$plugin"
            if declare -f enrich > /dev/null; then
                enrich || true
            fi
            break
        fi
    done < <(candidates)
} > "$ctx_file"

# Prune: contexts older than 7 days are useless (swaync CC caps retention).
find "$CTX_DIR" -name '*.env' -mmin +10080 -delete 2>/dev/null

exit 0

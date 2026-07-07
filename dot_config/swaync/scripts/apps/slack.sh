# swaync per-app plugin: Slack
#
# Problem: Slack's main process keeps no reference to the Electron
# Notification objects it creates (its retention list is never populated —
# see main.bundle.cjs), so V8 eventually garbage-collects them. Electron then
# nulls the native delegate (electron_api_notification.cc ~Notification), and
# shell/browser/notifications/notification.cc::NotificationClicked() silently
# discards clicks that arrive afterwards. The notification in swaync's
# control center stays perfectly valid — Slack has just forgotten what it
# meant.
#
# Recovery: Slack logs every notification it creates to browser.log
# (Store: NEW_NOTIFICATION) with teamId/channel/msg unredacted, milliseconds
# before emitting the D-Bus Notify. `enrich` correlates by arrival time and
# stores a message-precise slack:// deep link at receive; `on_action` fires
# it on every click — it targets the same message/thread Slack's own
# handler would, so a still-live handler racing us is harmless.
#
# Sourced by store-context.sh (enrich) and focus-sender.sh (on_action).

_slack_helper="$(dirname "${BASH_SOURCE[0]}")/../slack-notification-context.py"

enrich() {
    [ -n "${SWAYNC_TIME:-}" ] || return 0
    # Slack writes the log line ~ms before the Notify call; it's usually
    # already flushed, so try immediately and retry once for the race.
    local uri
    uri=$(python3 "$_slack_helper" deeplink "$SWAYNC_TIME" 3)
    if [ -z "$uri" ]; then
        sleep 0.5
        uri=$(python3 "$_slack_helper" deeplink "$SWAYNC_TIME" 3)
    fi
    [ -n "$uri" ] && printf 'DEEPLINK=%q\n' "$uri"
    return 0
}

on_action() {
    # $1 = context file (may not exist); DEEPLINK may be set from it.
    #
    # Fired unconditionally, no live-handler grace: the deep link carries
    # the same message/thread_ts parameters Slack's own click handler
    # navigates with, so when both run (fresh notification) they land on
    # the same view — idempotent, and stale clicks stay instant.
    local log="${XDG_RUNTIME_DIR:-/tmp}/swaync-focus-sender.log"

    local uri="${DEEPLINK:-}"
    # Not enriched at receive (e.g. log flush race) — try again now.
    if [ -z "$uri" ] && [ -n "${SWAYNC_TIME:-}" ]; then
        uri=$(python3 "$_slack_helper" deeplink "$SWAYNC_TIME")
    fi
    if [ -n "$uri" ]; then
        echo "$(date '+%F %T') slack notification click -> $uri" > "$log"
        # Forward straight to the running instance (slack.desktop Exec is
        # `slack %U`); xdg-open adds gio/launcher overhead on top of the
        # unavoidable Electron single-instance forwarding process.
        if command -v slack > /dev/null; then
            slack "$uri" > /dev/null 2>&1 &
        else
            xdg-open "$uri" > /dev/null 2>&1 &
        fi
    else
        echo "$(date '+%F %T') slack notification click, no context (id=${SWAYNC_ID:-?} time=${SWAYNC_TIME:-?})" > "$log"
    fi
    return 0
}

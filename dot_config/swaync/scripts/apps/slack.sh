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
# (Store: NEW_NOTIFICATION) with teamId/channel unredacted, milliseconds
# before emitting the D-Bus Notify. `enrich` correlates by arrival time and
# stores a slack:// deep link at receive; `on_action` fires it iff Slack
# didn't handle the click itself (a live handler logs
# Store: CLICK_NOTIFICATION and is thread-precise, so it wins).
#
# Sourced by store-context.sh (enrich) and focus-sender.sh (on_action).

_slack_helper="$(dirname "${BASH_SOURCE[0]}")/../slack-notification-context.py"

enrich() {
    [ -n "${SWAYNC_TIME:-}" ] || return 0
    # Slack writes the log line ~ms before the Notify call; give the file a
    # moment to flush, then correlate tightly.
    sleep 0.5
    local uri
    uri=$(python3 "$_slack_helper" deeplink "$SWAYNC_TIME" 3)
    [ -n "$uri" ] && printf 'DEEPLINK=%q\n' "$uri"
    return 0
}

on_action() {
    # $1 = context file (may not exist); DEEPLINK may be set from it.
    local log="${XDG_RUNTIME_DIR:-/tmp}/swaync-focus-sender.log"

    # Fresh notifications (< 90s) may still have a live in-app handler,
    # which is thread-precise and should win. Poll for its
    # CLICK_NOTIFICATION log entry instead of sleeping a fixed grace —
    # V8 GC almost never collects a notification that fast, so anything
    # older skips the wait entirely.
    local age=$(( $(date +%s) - ${SWAYNC_TIME:-0} ))
    if [ "$age" -lt 90 ]; then
        local i
        for i in 1 2 3 4 5 6; do
            sleep 0.2
            if [ -n "$(python3 "$_slack_helper" handled 5)" ]; then
                echo "$(date '+%F %T') slack handled click itself; deep link skipped" > "$log"
                return 0
            fi
        done
    fi

    local uri="${DEEPLINK:-}"
    # Not enriched at receive (e.g. log flush race) — try again now.
    if [ -z "$uri" ] && [ -n "${SWAYNC_TIME:-}" ]; then
        uri=$(python3 "$_slack_helper" deeplink "$SWAYNC_TIME")
    fi
    if [ -n "$uri" ]; then
        echo "$(date '+%F %T') stale slack notification -> $uri" > "$log"
        # Forward straight to the running instance (slack.desktop Exec is
        # `slack %U`); xdg-open adds gio/launcher overhead on top of the
        # unavoidable Electron single-instance forwarding process.
        if command -v slack > /dev/null; then
            slack "$uri" > /dev/null 2>&1 &
        else
            xdg-open "$uri" > /dev/null 2>&1 &
        fi
    else
        echo "$(date '+%F %T') stale slack notification, no context (id=${SWAYNC_ID:-?} time=${SWAYNC_TIME:-?})" > "$log"
    fi
    return 0
}

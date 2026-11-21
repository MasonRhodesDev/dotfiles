_slack_helper="$(dirname "${BASH_SOURCE[0]}")/slack-notification-context.py"

enrich() {
    [ -n "${SWAYNC_TIME:-}" ] || return 0
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
    local log="${XDG_RUNTIME_DIR:-/tmp}/swaync-focus-sender.log"

    local uri="${DEEPLINK:-}"
    if [ -z "$uri" ] && [ -n "${SWAYNC_TIME:-}" ]; then
        uri=$(python3 "$_slack_helper" deeplink "$SWAYNC_TIME")
    fi
    if [ -n "$uri" ]; then
        echo "$(date '+%F %T') slack notification click -> $uri" > "$log"
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

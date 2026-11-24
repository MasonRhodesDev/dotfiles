pi() {
    command node @home@/scripts/agent-status-pi.ts "$@"
}

codex() {
    if [[ -n ${KITTY_WINDOW_ID-} || $TERM == *kitty* ]]; then
        command node @home@/scripts/agent-status-codex.ts "$@"
    else
        command @home@/.local/bin/codex "$@"
    fi
}

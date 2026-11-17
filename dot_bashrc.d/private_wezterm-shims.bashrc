claude-track() {
    if [[ -z ${CLAUDECODE-} ]]; then
        echo "Error: Not in a Claude Code session"
        return 1
    fi
    if [[ -z ${WEZTERM_PANE-} ]]; then
        echo "Error: Not in WezTerm"
        return 1
    fi

    local projects_dir="$HOME/.claude/projects/-home-mason"

    local session_file
    session_file=$(stat -c '%W %n' "$projects_dir"/*.jsonl 2>/dev/null |
        grep -v agent | sort -rn | head -1 | awk '{print $2}')

    if [[ -z $session_file || ! -f $session_file ]]; then
        echo "Error: No session file found"
        return 1
    fi

    local session_id tty_device
    session_id=$(basename "$session_file" .jsonl)
    tty_device=$(wezterm cli list --format json 2>/dev/null |
        jq -r ".[] | select(.pane_id == $WEZTERM_PANE) | .tty_name" | head -1)
    [[ -z $tty_device ]] && tty_device=$(tty)

    local correlation_dir=/tmp/claude-wezterm
    mkdir -p "$correlation_dir"

    {
        echo "WEZTERM_PANE=$WEZTERM_PANE"
        echo "SESSION_FILE=$session_file"
        echo "TTY_DEVICE=$tty_device"
        echo "TIMESTAMP=$(date +%s)"
    } > "$correlation_dir/$session_id.pane"

    printf '\033]1337;SetUserVar=CLAUDE_ACTIVE=%s\007' "$(echo -n 1 | base64)" > "$tty_device" 2>/dev/null

    echo "✓ Tracking session: $session_id"
}

pi() {
    command node /home/mason/scripts/pi-wezterm.ts "$@"
}

codex() {
    if [[ -n ${WEZTERM_PANE-} || -n ${KITTY_WINDOW_ID-} || $TERM == *kitty* ]]; then
        command node /home/mason/scripts/codex-wezterm.ts "$@"
    else
        command /home/mason/.local/bin/codex "$@"
    fi
}

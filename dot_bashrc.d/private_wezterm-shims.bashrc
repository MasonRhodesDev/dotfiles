# WezTerm integration (port of the retired fish conf.d/wezterm.fish)

# Manual session tracking command (for sessions started without hooks)
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

    # Find the newest session file by creation time (birth time)
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

# pi/Codex hook commands cannot reliably set WezTerm user vars by writing
# directly to /dev/pts. Launch through foreground wrappers so OSC SetUserVar
# sequences are emitted on the pane stdout that WezTerm parses.
# Call the wrapper script directly (it handles the non-WezTerm case itself)
# instead of ~/.local/bin/pi — npm -g installs clobber that path with a plain
# symlink to cli.js. Use ~/scripts/pi-upgrade to upgrade pi safely.
pi() {
    command node /home/mason/scripts/pi-wezterm.ts "$@"
}

codex() {
    if [[ -n ${GT_ROLE-} ]]; then
        # Gas Town workers go through the agent-town shim so its GT_ROLE
        # model tiering keeps working; the header runner is skipped there.
        command /home/mason/.local/bin/codex "$@"
    elif [[ -n ${WEZTERM_PANE-} || -n ${KITTY_WINDOW_ID-} || $TERM == *kitty* ]]; then
        # TERM=*kitty* without the pane vars = far end of an ssh session from
        # kitty; the runner's OSC still reaches the local terminal.
        command node /home/mason/scripts/codex-wezterm.ts "$@"
    else
        command /home/mason/.local/bin/codex "$@"
    fi
}

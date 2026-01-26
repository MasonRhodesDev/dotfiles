# WezTerm integration for fish shell
# Export Claude Code session status as WezTerm user variable

# Manual session tracking command (for sessions started without hooks)
function claude-track
    if not set -q CLAUDECODE
        echo "Error: Not in a Claude Code session"
        return 1
    end

    if not set -q WEZTERM_PANE
        echo "Error: Not in WezTerm"
        return 1
    end

    set projects_dir "$HOME/.claude/projects/-home-mason"

    # Find the newest session file by creation time (birth time)
    # This is more reliable than modification time for multiple concurrent sessions
    set session_file (stat -c '%W %n' $projects_dir/*.jsonl 2>/dev/null | \
        grep -v agent | \
        sort -rn | \
        head -1 | \
        awk '{print $2}')

    if test -z "$session_file"; or not test -f "$session_file"
        echo "Error: No session file found"
        return 1
    end

    # Extract session ID from filename
    set session_id (basename $session_file .jsonl)

    # Get TTY device for this pane
    set tty_device (wezterm cli list --format json 2>/dev/null | jq -r ".[] | select(.pane_id == $WEZTERM_PANE) | .tty_name" | head -1)
    if test -z "$tty_device"
        set tty_device (tty)
    end

    # Create correlation file
    set correlation_dir "/tmp/claude-wezterm"
    mkdir -p $correlation_dir

    echo "WEZTERM_PANE=$WEZTERM_PANE" > "$correlation_dir/$session_id.pane"
    echo "SESSION_FILE=$session_file" >> "$correlation_dir/$session_id.pane"
    echo "TTY_DEVICE=$tty_device" >> "$correlation_dir/$session_id.pane"
    echo "TIMESTAMP="(date +%s) >> "$correlation_dir/$session_id.pane"

    # Set CLAUDE_ACTIVE user variable by writing to TTY
    printf '\033]1337;SetUserVar=CLAUDE_ACTIVE=%s\007' (echo -n "1" | base64) > $tty_device 2>/dev/null

    # Start watcher with session ID
    nohup /home/mason/scripts/wezterm-claude-watcher $session_id >/dev/null 2>&1 &
    disown

    echo "✓ Tracking session: $session_id"
end

# Auto-detection removed - now handled by SessionStart hook
# Use claude-track command to manually register sessions if needed

# WezTerm integration for zsh shell
# Export Claude Code session status as WezTerm user variable

# Only run in WezTerm
if [[ -n "$WEZTERM_PANE" ]]; then
    # Export CLAUDECODE status to WezTerm via OSC sequence
    if [[ "$CLAUDECODE" == "1" ]]; then
        # Set user variable: CLAUDE_ACTIVE=1 (base64 encoded: MQ==)
        printf '\033]1337;SetUserVar=CLAUDE_ACTIVE=%s\007' "$(echo -n "1" | base64)"

        # Create marker file to correlate this session to its session file
        # Find the most recently modified session file (should be this session's file)
        local projects_dir="$HOME/.claude/projects/-home-mason"
        local session_file=$(ls -t "$projects_dir"/*.jsonl 2>/dev/null | grep -v agent | head -1)

        if [[ -n "$session_file" ]]; then
            # Write session file path to marker file using parent PID as identifier
            echo "$session_file" > "/tmp/claude-session-$PPID"

            # Start background watcher for event-driven activity updates
            # Pass the parent's TTY so the watcher can send OSC sequences back to this terminal
            # (using parent PID because Claude's bash subprocess doesn't have a TTY)
            local tty_device="/dev/$(ps -o tty= -p $PPID)"
            nohup /home/mason/scripts/wezterm-claude-watcher "$tty_device" "$PPID" >/dev/null 2>&1 &
            disown
        fi
    fi
fi

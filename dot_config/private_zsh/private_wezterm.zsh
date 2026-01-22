# WezTerm integration for zsh shell
# Export Claude Code session status as WezTerm user variable

# Function to manually register current Claude session for activity tracking
claude-track() {
    if [[ "$CLAUDECODE" != "1" ]]; then
        echo "Error: Not in a Claude Code session"
        return 1
    fi

    local projects_dir="$HOME/.claude/projects/-home-mason"
    local session_file=$(ls -t "$projects_dir"/*.jsonl 2>/dev/null | grep -v agent | head -1)

    if [[ -z "$session_file" ]]; then
        echo "Error: No session file found"
        return 1
    fi

    # Extract session slug for display
    local slug=$(grep -m 1 '"slug":' "$session_file" 2>/dev/null | jq -r '.slug' 2>/dev/null | sed 's/-/ /g')

    # Write to marker file
    echo "$session_file" > "/tmp/claude-session-$PPID"

    # Send activity update to WezTerm
    local tty_device="/dev/$(ps -o tty= -p $PPID)"
    if [[ -n "$slug" ]]; then
        printf '\033]1337;SetUserVar=CLAUDE_ACTIVITY=%s\007' "$(echo -n "$slug" | head -c 40 | base64)" > "$tty_device" 2>/dev/null
        echo "✓ Tracking session: $slug"
    else
        echo "✓ Tracking session: $(basename "$session_file" .jsonl)"
    fi
}

# Only run in WezTerm
if [[ -n "$WEZTERM_PANE" ]]; then
    # Export CLAUDECODE status to WezTerm via OSC sequence
    if [[ "$CLAUDECODE" == "1" ]]; then
        # Only run once per Claude session (check if watcher already exists)
        if ! pgrep -f "wezterm-claude-watcher.*$PPID" >/dev/null 2>&1; then
            # Set user variable: CLAUDE_ACTIVE=1 (base64 encoded: MQ==)
            # Send to parent's TTY to avoid showing in command output
            local tty_device="/dev/$(ps -o tty= -p $PPID)"
            printf '\033]1337;SetUserVar=CLAUDE_ACTIVE=%s\007' "$(echo -n "1" | base64)" > "$tty_device" 2>/dev/null

            # Start background watcher (waits for manual registration via claude-track)
            nohup /home/mason/scripts/wezterm-claude-watcher "$tty_device" "$PPID" >/dev/null 2>&1 &
            disown
        fi
    fi
fi

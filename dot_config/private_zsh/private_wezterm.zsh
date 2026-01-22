# WezTerm integration for zsh shell
# Export Claude Code session status as WezTerm user variable

# Only run in WezTerm
if [[ -n "$WEZTERM_PANE" ]]; then
    # Export CLAUDECODE status to WezTerm via OSC sequence
    if [[ "$CLAUDECODE" == "1" ]]; then
        # Set user variable: CLAUDE_ACTIVE=1 (base64 encoded: MQ==)
        printf '\033]1337;SetUserVar=CLAUDE_ACTIVE=%s\007' "$(echo -n "1" | base64)"

        # Start background watcher for event-driven activity updates
        # Each Claude session gets its own watcher (per-session scoped)
        # The watcher correlates to this session by watching the most recently modified file
        # Pass the parent's TTY so the watcher can send OSC sequences back to this terminal
        # (using parent PID because Claude's bash subprocess doesn't have a TTY)
        local tty_device="/dev/$(ps -o tty= -p $PPID)"
        nohup /home/mason/scripts/wezterm-claude-watcher "$tty_device" >/dev/null 2>&1 &
        disown
    fi
fi

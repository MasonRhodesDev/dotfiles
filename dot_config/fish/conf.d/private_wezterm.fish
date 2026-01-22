# WezTerm integration for fish shell
# Export Claude Code session status as WezTerm user variable

# Only run in WezTerm
if set -q WEZTERM_PANE
    # Export CLAUDECODE status to WezTerm via OSC sequence
    if set -q CLAUDECODE
        # Set user variable: CLAUDE_ACTIVE=1 (base64 encoded: MQ==)
        printf '\033]1337;SetUserVar=CLAUDE_ACTIVE=%s\007' (echo -n "1" | base64)

        # Get parent PID for marker file
        set ppid (ps -o ppid= -p %self | string trim)

        # Start background watcher that will auto-detect which session file belongs to this session
        # Pass the parent's TTY so the watcher can send OSC sequences back to this terminal
        # (using parent PID because Claude's bash subprocess doesn't have a TTY)
        set tty_device "/dev/"(ps -o tty= -p $ppid)
        nohup /home/mason/scripts/wezterm-claude-watcher $tty_device $ppid >/dev/null 2>&1 &
        disown
    end
end

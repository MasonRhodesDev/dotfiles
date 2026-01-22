# WezTerm integration for fish shell
# Export Claude Code session status as WezTerm user variable

# Only run in WezTerm
if set -q WEZTERM_PANE
    # Export CLAUDECODE status to WezTerm via OSC sequence
    if set -q CLAUDECODE
        # Get parent PID for marker file
        set ppid (ps -o ppid= -p %self | string trim)

        # Only run once per Claude session (check if watcher already exists)
        if not pgrep -f "wezterm-claude-watcher.*$ppid" >/dev/null 2>&1
            # Set user variable: CLAUDE_ACTIVE=1 (base64 encoded: MQ==)
            # Send to parent's TTY to avoid showing in command output
            set tty_device "/dev/"(ps -o tty= -p $ppid)
            printf '\033]1337;SetUserVar=CLAUDE_ACTIVE=%s\007' (echo -n "1" | base64) > $tty_device 2>/dev/null

            # Start background watcher that will auto-detect which session file belongs to this session
            nohup /home/mason/scripts/wezterm-claude-watcher $tty_device $ppid >/dev/null 2>&1 &
            disown
        end
    end
end

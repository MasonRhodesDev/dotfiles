# WezTerm integration for fish shell
# Export Claude Code session status as WezTerm user variable

# Function to manually register current Claude session for activity tracking
function claude-track
    if not set -q CLAUDECODE
        echo "Error: Not in a Claude Code session"
        return 1
    end

    set projects_dir "$HOME/.claude/projects/-home-mason"
    set session_file (ls -t $projects_dir/*.jsonl 2>/dev/null | grep -v agent | head -1)

    if test -z "$session_file"
        echo "Error: No session file found"
        return 1
    end

    # Extract session slug for display
    set slug (grep -m 1 '"slug":' $session_file 2>/dev/null | jq -r '.slug' 2>/dev/null | sed 's/-/ /g')

    # Get parent PID
    set ppid (ps -o ppid= -p %self | string trim)

    # Write to marker file
    echo $session_file > /tmp/claude-session-$ppid

    # Send activity update to WezTerm
    set tty_device "/dev/"(ps -o tty= -p $ppid)
    if test -n "$slug"
        printf '\033]1337;SetUserVar=CLAUDE_ACTIVITY=%s\007' (echo -n "$slug" | head -c 40 | base64) > $tty_device 2>/dev/null
        echo "✓ Tracking session: $slug"
    else
        echo "✓ Tracking session: "(basename $session_file .jsonl)
    end
end

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

            # Start background watcher (waits for manual registration via claude-track)
            nohup /home/mason/scripts/wezterm-claude-watcher $tty_device $ppid >/dev/null 2>&1 &
            disown
        end
    end
end

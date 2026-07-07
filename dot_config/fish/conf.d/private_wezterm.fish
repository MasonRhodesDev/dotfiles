# WezTerm integration for fish shell

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
    set session_file (stat -c '%W %n' $projects_dir/*.jsonl 2>/dev/null | \
        grep -v agent | \
        sort -rn | \
        head -1 | \
        awk '{print $2}')

    if test -z "$session_file"; or not test -f "$session_file"
        echo "Error: No session file found"
        return 1
    end

    set session_id (basename $session_file .jsonl)
    set tty_device (wezterm cli list --format json 2>/dev/null | jq -r ".[] | select(.pane_id == $WEZTERM_PANE) | .tty_name" | head -1)
    if test -z "$tty_device"
        set tty_device (tty)
    end

    set correlation_dir "/tmp/claude-wezterm"
    mkdir -p $correlation_dir

    echo "WEZTERM_PANE=$WEZTERM_PANE" > "$correlation_dir/$session_id.pane"
    echo "SESSION_FILE=$session_file" >> "$correlation_dir/$session_id.pane"
    echo "TTY_DEVICE=$tty_device" >> "$correlation_dir/$session_id.pane"
    echo "TIMESTAMP="(date +%s) >> "$correlation_dir/$session_id.pane"

    printf '\033]1337;SetUserVar=CLAUDE_ACTIVE=%s\007' (echo -n "1" | base64) > $tty_device 2>/dev/null

    echo "✓ Tracking session: $session_id"
end

# pi/Codex hook commands cannot reliably set WezTerm user vars by writing
# directly to /dev/pts. Launch through foreground wrappers so OSC SetUserVar
# sequences are emitted on the pane stdout that WezTerm parses.
# Call the wrapper script directly (it handles the non-WezTerm case itself)
# instead of ~/.local/bin/pi — npm -g installs clobber that path with a plain
# symlink to cli.js. Use ~/scripts/pi-upgrade to upgrade pi safely.
function pi
    command node /home/mason/scripts/pi-wezterm.ts $argv
end

function codex
    if set -q WEZTERM_PANE
        command node /home/mason/scripts/codex-wezterm.ts $argv
    else
        command /home/mason/.local/bin/codex $argv
    end
end

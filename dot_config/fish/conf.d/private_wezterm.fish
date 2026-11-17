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

function pi
    command node /home/mason/scripts/pi-wezterm.ts $argv
end

function codex
    if set -q GT_ROLE
        command /home/mason/.local/bin/codex $argv
    else if set -q WEZTERM_PANE; or set -q KITTY_WINDOW_ID; or string match -q '*kitty*' -- $TERM
        command node /home/mason/scripts/codex-wezterm.ts $argv
    else
        command /home/mason/.local/bin/codex $argv
    end
end

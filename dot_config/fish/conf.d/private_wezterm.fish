# WezTerm integration for fish shell
# Export Claude Code session status as WezTerm user variable

# Only run in WezTerm
if set -q WEZTERM_PANE
    # Export CLAUDECODE status to WezTerm via OSC sequence
    if set -q CLAUDECODE
        # Set user variable: CLAUDE_ACTIVE=1 (base64 encoded: MQ==)
        printf '\033]1337;SetUserVar=CLAUDE_ACTIVE=%s\007' (echo -n "1" | base64)
    end
end

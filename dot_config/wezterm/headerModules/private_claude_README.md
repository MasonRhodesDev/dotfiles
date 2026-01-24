# Claude Module

The Claude header module displays the current Claude Code session activity in your WezTerm status bar.

## Features

- Shows "🤖 Claude" when Claude Code is active
- Displays current working directory
- Shows session activity (e.g., "🤖 Reading files | ~/repos/project")
- Updates in real-time via background watcher

## Display Format

```
🤖 Claude | ~/repos/project
🤖 Reading files | ~/repos/project
```

## How It Works

The Claude module uses WezTerm user variables to communicate between the shell and the header module:

1. **`CLAUDE_ACTIVE`** - Set to "1" when Claude Code session is detected
2. **`CLAUDE_ACTIVITY`** - Contains the current activity description (e.g., "Reading files")

## Required Configuration

The Claude module requires additional shell configuration and background scripts to function properly.

### Shell Integration

**Fish Shell:**
[`dot_config/fish/conf.d/private_wezterm.fish`](../../fish/conf.d/private_wezterm.fish)

**Zsh:**
[`dot_config/private_zsh/private_wezterm.zsh`](../../private_zsh/private_wezterm.zsh)

These files:
- Detect when Claude Code is running (via `$CLAUDECODE` environment variable)
- Set the `CLAUDE_ACTIVE` user variable
- Launch the background watcher script
- Provide `claude-track` command to manually register sessions

### Background Scripts

The shell integration uses these scripts to track Claude activity. These are registered as hooks in `~/.claude/settings.json`:

1. **[`scripts/executable_wezterm-claude-session-hook`](../../../scripts/executable_wezterm-claude-session-hook)**
   - **Registered:** [`settings.json:33`](../../../.claude/settings.json#L33) (SessionStart hook)
   - Manages session lifecycle
   - Initializes tracking for new sessions

2. **[`scripts/executable_wezterm-claude-activity-hook`](../../../scripts/executable_wezterm-claude-activity-hook)**
   - **Registered:** [`settings.json:37,48,59,70`](../../../.claude/settings.json#L37) (SessionStart, UserPromptSubmit, PostToolUse, Stop hooks)
   - Monitors Claude Code session files for activity
   - Updates `CLAUDE_ACTIVITY` user variable with current operation

3. **[`scripts/executable_wezterm-claude-cleanup-hook`](../../../scripts/executable_wezterm-claude-cleanup-hook)**
   - **Registered:** [`settings.json:81`](../../../.claude/settings.json#L81) (SessionEnd hook)
   - Cleans up marker files when session ends
   - Resets user variables

4. **[`scripts/executable_wezterm-claude-summarize`](../../../scripts/executable_wezterm-claude-summarize)**
   - Helper script (called by activity hook)
   - Generates human-readable activity summaries
   - Formats session slug for display

## Manual Session Tracking

If automatic detection fails, you can manually register a session:

```fish
claude-track
```

This command:
1. Finds the most recent Claude session file
2. Creates a marker file for tracking
3. Updates the WezTerm status bar with session info

## Technical Details

### User Variable Communication

WezTerm user variables are set using OSC (Operating System Command) escape sequences:

```fish
printf '\033]1337;SetUserVar=CLAUDE_ACTIVE=%s\007' (echo -n "1" | base64)
```

The module reads these variables via `pane:get_user_vars()`.

### Detection Methods

The module detects Claude Code sessions using multiple methods (in order):

1. **Process name** - Checks if foreground process is `claude`
2. **User variable** - Checks if `CLAUDE_ACTIVE == "1"`
3. **Window title** - Checks if window title contains "claude"

### Background Watcher

The watcher script (`wezterm-claude-watcher`):
- Monitors `/tmp/claude-session-$PPID` marker files
- Tails the session JSONL file for new entries
- Parses activity from the session log
- Updates `CLAUDE_ACTIVITY` user variable in real-time
- Exits when shell process terminates

## Disabling the Module

To disable the Claude module, simply delete or rename this file:

```bash
rm ~/.config/wezterm/headerModules/claude.lua
# or
mv ~/.config/wezterm/headerModules/claude.lua{,.disabled}
```

The module loader will skip it on next reload.

## Troubleshooting

### Module not showing

1. **Verify Claude Code is running:**
   ```bash
   echo $CLAUDECODE  # Should be non-empty
   ```

2. **Check user variables:**
   ```lua
   -- In WezTerm debug console (Ctrl+Shift+L)
   local pane = window:active_pane()
   local vars = pane:get_user_vars()
   wezterm.log_info("CLAUDE_ACTIVE: " .. tostring(vars.CLAUDE_ACTIVE))
   ```

3. **Verify watcher is running:**
   ```bash
   ps aux | grep wezterm-claude-watcher
   ```

4. **Check logs:**
   ```bash
   journalctl --user -u wezterm -f
   ```

### Activity not updating

1. **Manually register session:**
   ```bash
   claude-track
   ```

2. **Restart watcher:**
   ```bash
   pkill -f wezterm-claude-watcher
   # Shell integration will auto-restart it
   ```

3. **Check marker file exists:**
   ```bash
   ls -la /tmp/claude-session-*
   ```

## Related Files

- **Main config:** [`dot_config/wezterm/wezterm.lua`](../wezterm.lua)
- **Module loader:** [`dot_config/wezterm/headerModulesLoader.lua`](../headerModulesLoader.lua)
- **Claude module:** [`dot_config/wezterm/headerModules/claude.lua`](./claude.lua)

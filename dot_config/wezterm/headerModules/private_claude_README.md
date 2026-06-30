# Pane Status Modules

The status bar primarily displays a pane-local summary of what the terminal pane is doing. Agent hook status still exists as metadata/fallback for Claude Code, pi, and Codex.

## Core rule

The visible status should answer: "what is this pane doing right now?"

Pane summaries are generated from recent WezTerm buffer text by `/home/mason/scripts/wezterm-pane-summarizer.ts`. Agent lifecycle hooks are no longer the primary display text. The system does not infer from cwd matching, latest session files, or shared history logs.

## Display Format

```text
◌ running tests
◌ debugging failing tests
◌ reviewing errors
◌ running pi session
```

## Pane Summary

`/home/mason/scripts/wezterm-pane-summarizer.ts`

- Lists WezTerm panes.
- Reads recent pane text with `wezterm cli get-text`.
- Redacts obvious secrets before summarization.
- Uses local Ollama by default (`WEZTERM_PANE_SUMMARY_MODEL`, default `qwen2.5-coder:1.5b`) with a short status-bar prompt.
- Samples frequently but only summarizes after the pane buffer has been quiet/stable for a few seconds.
- Falls back to a conservative local classifier if the local model call fails.
- Writes summary state to `$XDG_RUNTIME_DIR/wezterm-pane-summary/pane-<pane_id>.json` or `~/.cache/wezterm-pane-summary/pane-<pane_id>.json`.
- Runs as a daemon started by WezTerm `gui-startup`; can also be started manually:

```sh
node /home/mason/scripts/wezterm-pane-summarizer.ts daemon
```

For agent panes, fresh medium/high-confidence pane summaries replace only the activity text inside the existing agent header, preserving the agent icon/name/model. For non-agent panes, `pane_summary.lua` can render a standalone `◌ <summary>` fallback. Low-confidence fallbacks are written for debugging but not rendered.

The prompt asks for one short phrase describing what is being done now in the pane. It forbids quoting terminal text and rejects vague outputs like `working in terminal`.

## User Variable Protocol

New integrations use numeric WezTerm user variables as pane-local refresh signals:

| Variable | Meaning |
|---|---|
| `AGENT_ACTIVE` | `1` while the pane owns an active agent status; `0` clears it |
| `AGENT_KIND` | Numeric agent code: `1` pi, `2` Codex, `3` Claude |
| `AGENT_SEQ` | Monotonic numeric refresh signal for status changes |

String details (`agent`, `model`, `state`, `activity`, `sessionId`) live in the explicit hook-fed pane state file. This is necessary because WezTerm `20260501_010510_805a1c7b` accepts numeric-looking `SetUserVar` values but ignores arbitrary string values such as `pi` or `Running command`.

Legacy Claude vars remain supported:

| Variable | Meaning |
|---|---|
| `CLAUDE_ACTIVE` | Legacy Claude active flag |
| `CLAUDE_ACTIVITY` | Legacy Claude activity text |
| `CLAUDE_MODEL` | Legacy Claude model |

## Transport

Do not write OSC sequences directly to `/dev/pts/*`; that does not reliably trigger WezTerm `user-var-changed`.

The working transport is:

1. Agent lifecycle hook calls `/home/mason/scripts/wezterm-agent-bridge.ts`.
2. The bridge writes explicit pane/session state under `$XDG_RUNTIME_DIR/wezterm-agent-status/<agent>/` when available, otherwise `~/.cache/wezterm-agent-status/<agent>/`.
3. The foreground launcher watches that pane state file only when `stdout` is a TTY.
4. The launcher emits numeric OSC 1337 `SetUserVar` signals (`AGENT_ACTIVE`, `AGENT_KIND`, `AGENT_SEQ`) to stdout.
5. WezTerm receives the OSC output and updates pane-local user variables.
6. The Lua module reads the explicit pane state file keyed by the WezTerm pane id.

## Implementation

### Shared bridge

`/home/mason/scripts/wezterm-agent-bridge.ts`

- Reads hook JSON from stdin.
- Writes explicit hook-fed state files under the user-private runtime root:
  - `<state-root>/<agent>/<session>.json`
  - `<state-root>/<agent>/pane-<WEZTERM_PANE>.json`
- Does not infer from shared logs or cwd.
- Does not write OSC directly to `/dev/pts/*`.

### Shared runner

`/home/mason/scripts/wezterm-agent-runner.ts`

- Spawns the real agent CLI.
- Watches the pane state file when running in WezTerm with TTY stdout.
- Emits numeric `AGENT_ACTIVE`/`AGENT_KIND`/`AGENT_SEQ` via OSC 1337 `SetUserVar` to stdout, never into redirected/captured stdout.
- Clears `AGENT_*` when the agent exits.

### pi

`/home/mason/.pi/agent/extensions/wezterm-agent-status.ts`

pi status is fed by native lifecycle events:

- `session_start`
- `before_agent_start`
- `agent_start`
- `tool_execution_start`
- `tool_execution_end`
- `agent_end`
- `turn_end`
- `model_select`
- `session_shutdown`

Normal shell launches use `/home/mason/.local/bin/pi`, which is now a small Node launcher. In WezTerm it delegates to `/home/mason/scripts/wezterm-agent-runner.ts`; outside WezTerm it runs the real pi CLI directly at `/home/mason/.local/lib/node_modules/@earendil-works/pi-coding-agent/dist/cli.js`.

`/home/mason/scripts/pi-wezterm.ts` remains as the explicit wrapper entrypoint.

### Codex

`/home/mason/.codex/hooks.json`

Codex status is fed by lifecycle hooks:

- `SessionStart`
- `UserPromptSubmit`
- `PreToolUse`
- `PostToolUse`
- `Stop`

Codex requires hook trust review. After changing hooks, start Codex and use `/hooks` to review/trust the hook definitions.

Normal shell launches use:

`/home/mason/scripts/codex-wezterm.ts`

### Shell entrypoints

Wrapper functions are in:

- `/home/mason/.config/fish/conf.d/wezterm.fish`
- `/home/mason/.config/zsh/wezterm.zsh`

For pi, `/home/mason/.local/bin/pi` also routes through the wrapper, so shell function loading is no longer required for pi status. Codex still depends on the shell function unless `/home/mason/scripts/codex-wezterm.ts` is launched directly.

### Claude

Claude keeps the existing hook scripts for now:

- `/home/mason/scripts/wezterm-claude-session-hook`
- `/home/mason/scripts/wezterm-claude-activity-hook`
- `/home/mason/scripts/wezterm-claude-cleanup-hook`
- `/home/mason/scripts/wezterm-claude-summarize`

The Lua module supports both legacy `CLAUDE_*` and generic `AGENT_*` variables.

## Troubleshooting

### No status appears

The Lua module renders only explicit hook-fed state: numeric `AGENT_*` pane variables plus the matching pane state file, or legacy `CLAUDE_*` pane variables. If no status appears, the wrapper/hook path has not emitted pane variables yet or the pane state file is missing.

### pi status does not update

1. Confirm `pi` resolves to the launcher:
   ```sh
   type pi
   ls -l /home/mason/.local/bin/pi
   ```
2. Confirm state is being written:
   ```sh
   state_root="${XDG_RUNTIME_DIR:+$XDG_RUNTIME_DIR/wezterm-agent-status}"
   state_root="${state_root:-$HOME/.cache/wezterm-agent-status}"
   ls -la "$state_root/pi"
   ```
3. Reload or restart pi after extension changes.

### Codex status does not update

1. Confirm hooks exist:
   ```sh
   jq empty /home/mason/.codex/hooks.json
   ```
2. Start Codex and run `/hooks` to trust the hook definitions.
3. Confirm your shell uses the wrapper:
   ```sh
   type codex
   ```

### Status remains after exit

The wrappers clear `AGENT_*` on process exit. If status remains, the session probably was not launched through the wrapper.

## Automated validation

Run:

```sh
node /home/mason/scripts/test-wezterm-agent-status.ts
```

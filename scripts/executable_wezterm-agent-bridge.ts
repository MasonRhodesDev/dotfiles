#!/usr/bin/env node
import { chmodSync, mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';

const agent = (process.argv[2] ?? '').toLowerCase();
const clear = process.argv.includes('--clear');
const knownAgents = new Set(['claude', 'codex', 'pi']);

interface HookPayload {
  hook_event_name?: string;
  hookEventName?: string;
  session_id?: string;
  turn_id?: string;
  cwd?: string;
  model?: string;
  prompt?: string;
  tool_name?: string;
  toolName?: string;
  state?: string;
  activity?: string;
}

interface StoredState {
  active: boolean;
  agent: string;
  sessionId: string;
  pane?: string;
  model?: string;
  activity?: string;
  state?: string;
  updatedAt: string;
  updatedAtMs?: number;
}

function readStdin(): string {
  if (process.stdin.isTTY) return '';
  try {
    return readFileSync(0, 'utf8');
  } catch {
    return '';
  }
}

function parsePayload(input: string): HookPayload {
  if (!input.trim()) return {};
  try {
    return JSON.parse(input) as HookPayload;
  } catch {
    return {};
  }
}

function safeName(value: string): string {
  return value.replace(/[^a-zA-Z0-9_.-]/g, '_');
}

function stateRoot(): string {
  const base = process.env.XDG_RUNTIME_DIR && process.env.XDG_RUNTIME_DIR !== ''
    ? process.env.XDG_RUNTIME_DIR
    : join(process.env.HOME ?? '.', '.cache');
  const root = join(base, 'wezterm-agent-status');
  mkdirSync(root, { recursive: true, mode: 0o700 });
  try {
    chmodSync(root, 0o700);
  } catch {
    // Best effort; the directory may be on a filesystem that ignores chmod.
  }
  return root;
}

function stateDir(): string {
  return join(stateRoot(), agent);
}

function sessionStatePath(sessionId: string): string {
  return join(stateDir(), `${safeName(sessionId)}.json`);
}

function paneStatePath(pane: string): string {
  return join(stateDir(), `pane-${safeName(pane)}.json`);
}

function readJson(path: string): StoredState | undefined {
  try {
    return JSON.parse(readFileSync(path, 'utf8')) as StoredState;
  } catch {
    return undefined;
  }
}

function readPrevious(sessionId: string, pane?: string): StoredState | undefined {
  return readJson(sessionStatePath(sessionId)) ?? (pane ? readJson(paneStatePath(pane)) : undefined);
}

function writeJson(path: string, state: StoredState): void {
  mkdirSync(dirname(path), { recursive: true, mode: 0o700 });
  const tempPath = `${path}.${process.pid}.${Date.now()}.tmp`;
  writeFileSync(tempPath, `${JSON.stringify(state, null, 2)}\n`, { mode: 0o600 });
  renameSync(tempPath, path);
}

function writeState(state: StoredState): void {
  writeJson(sessionStatePath(state.sessionId), state);
  if (state.pane) writeJson(paneStatePath(state.pane), state);
}

function nextStatus(payload: HookPayload, previous?: StoredState): Pick<StoredState, 'state' | 'activity' | 'model'> {
  const event = payload.hook_event_name ?? payload.hookEventName ?? '';
  const toolName = payload.tool_name ?? payload.toolName ?? '';
  const model = payload.model ?? (event === 'SessionStart' ? '' : previous?.model ?? '');

  if (payload.state || payload.activity) {
    return {
      model,
      state: payload.state ?? previous?.state ?? 'idle',
      activity: '',
    };
  }

  switch (event) {
    case 'SessionStart':
      return { model, state: 'idle', activity: '' };
    case 'UserPromptSubmit':
    case 'BeforeAgentStart':
      return { model, state: 'working', activity: '' };
    case 'AgentStart':
      return { model, state: 'working', activity: '' };
    case 'PreToolUse':
    case 'ToolExecutionStart':
      return { model, state: 'tool', activity: '' };
    case 'PostToolUse':
    case 'ToolExecutionEnd':
      return { model, state: 'working', activity: '' };
    case 'Stop':
    case 'AgentEnd':
    case 'TurnEnd':
      return { model, state: 'idle', activity: '' };
    case 'ModelSelect':
      return { model, state: previous?.state ?? 'idle', activity: '' };
    default:
      return { model, state: previous?.state ?? 'idle', activity: '' };
  }
}

function maybeCodexHookResponse(payload: HookPayload): void {
  if (agent !== 'codex') return;
  if (!(payload.hook_event_name ?? payload.hookEventName)) return;
  process.stdout.write('{}\n');
}

const input = readStdin();
const payload = parsePayload(input);

try {
  if (!knownAgents.has(agent)) process.exit(0);

  // Pane identity: wezterm pane id, or kitty pid + window id (the pid is in
  // the key because Hyprland runs one kitty instance per OS window, so every
  // window's id is 1 and the id alone collides across instances).
  // TERM decides the terminal: stale WEZTERM_PANE survives nested terminal
  // launches, but TERM is always set by the terminal that owns the pty.
  const inKitty = (process.env.TERM ?? '').includes('kitty') && Boolean(process.env.KITTY_WINDOW_ID);
  const kittyPane = process.env.KITTY_WINDOW_ID
    ? `kitty-${process.env.KITTY_PID ?? '0'}-${process.env.KITTY_WINDOW_ID}`
    : undefined;
  const pane = inKitty ? kittyPane : process.env.WEZTERM_PANE ?? kittyPane;
  const sessionId = payload.session_id ?? pane ?? `${agent}-${process.ppid}`;

  if (clear) {
    writeState({
      active: false,
      agent,
      sessionId,
      pane,
      model: '',
      activity: '',
      state: '',
      updatedAt: new Date().toISOString(),
      updatedAtMs: Date.now(),
    });
    maybeCodexHookResponse(payload);
    process.exit(0);
  }

  const previous = readPrevious(sessionId, pane);
  const status = nextStatus(payload, previous);

  writeState({
    active: true,
    agent,
    sessionId,
    pane,
    model: status.model ?? '',
    activity: status.activity ?? '',
    state: status.state ?? 'idle',
    updatedAt: new Date().toISOString(),
    updatedAtMs: Date.now(),
  });

  maybeCodexHookResponse(payload);
} catch {
  maybeCodexHookResponse(payload);
  process.exit(0);
}

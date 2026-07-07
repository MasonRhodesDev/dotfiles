#!/usr/bin/env node
import { chmodSync, existsSync, mkdirSync, readFileSync, unwatchFile, watchFile, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { spawn } from 'node:child_process';

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

const [agent, realScript, ...agentArgs] = process.argv.slice(2);

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

function paneStatePath(agentName: string, pane: string): string {
  return join(stateRoot(), agentName, `pane-${safeName(pane)}.json`);
}

function writeInactivePaneState(): void {
  if (!pane) return;
  const dir = join(stateRoot(), agent);
  mkdirSync(dir, { recursive: true, mode: 0o700 });
  writeFileSync(paneStatePath(agent, pane), `${JSON.stringify({
    active: false,
    agent,
    sessionId: pane,
    pane,
    model: '',
    activity: '',
    state: '',
    updatedAt: new Date().toISOString(),
    updatedAtMs: Date.now(),
  }, null, 2)}\n`, { mode: 0o600 });
}

function setUserVar(name: string, value: string): void {
  const encoded = Buffer.from(value, 'utf8').toString('base64');
  process.stdout.write(`\x1b]1337;SetUserVar=${name}=${encoded}\x07`);
}

function emitVars(vars: Record<string, string>): void {
  for (const [name, value] of Object.entries(vars)) {
    setUserVar(name, value);
  }
}

function nextSeq(): string {
  sequence = Math.max(Date.now(), sequence + 1);
  return String(sequence);
}

function agentKind(agentName: string): string {
  if (agentName === 'pi') return '1';
  if (agentName === 'codex') return '2';
  if (agentName === 'claude') return '3';
  return '0';
}

function clearStatus(): void {
  emitVars({
    AGENT_ACTIVE: '0',
    AGENT_KIND: '0',
    AGENT_SEQ: nextSeq(),
  });
}

function emitState(state: StoredState): void {
  if (!state.active) {
    clearStatus();
    return;
  }

  // This WezTerm build accepts numeric-looking SetUserVar values reliably but
  // ignores arbitrary strings. AGENT_ACTIVE/AGENT_SEQ are pane-local refresh
  // signals; string details are read by Lua from the explicit state file.
  emitVars({
    AGENT_ACTIVE: '1',
    AGENT_KIND: agentKind(state.agent),
    AGENT_SEQ: nextSeq(),
  });
}

function readText(path: string): string {
  try {
    return readFileSync(path, 'utf8');
  } catch {
    return '';
  }
}

function readStateText(stateText: string): StoredState | undefined {
  if (!stateText) return undefined;
  try {
    return JSON.parse(stateText) as StoredState;
  } catch {
    return undefined;
  }
}

function signalExitCode(signal: NodeJS.Signals): number {
  const signals: Partial<Record<NodeJS.Signals, number>> = {
    SIGHUP: 1,
    SIGINT: 2,
    SIGTERM: 15,
  };
  return 128 + (signals[signal] ?? 0);
}

if (!agent || !realScript) {
  console.error('wezterm-agent-runner: usage: wezterm-agent-runner.ts <agent> <real-cli-js> [args...]');
  process.exit(64);
}

if (!existsSync(realScript)) {
  console.error(`wezterm-agent-runner: real CLI not found at ${realScript}`);
  process.exit(127);
}

// Pane identity: wezterm pane id, or kitty window id (prefixed — both are
// small integers and share the same state-file namespace). kitty interprets
// the same OSC 1337 SetUserVar sequences emitted below.
// TERM decides the terminal: env vars like WEZTERM_PANE survive nested
// terminal launches (kitty opened from a wezterm shell still carries it),
// but TERM is always overridden by the terminal that owns the pty.
const inKitty = (process.env.TERM ?? '').includes('kitty') && Boolean(process.env.KITTY_WINDOW_ID);
const pane = inKitty
  ? `kitty-${process.env.KITTY_WINDOW_ID}`
  : process.env.WEZTERM_PANE
    ?? (process.env.KITTY_WINDOW_ID ? `kitty-${process.env.KITTY_WINDOW_ID}` : undefined);
const shouldEmitStatus = Boolean(pane && process.stdout.isTTY);
const path = shouldEmitStatus && pane ? paneStatePath(agent, pane) : undefined;
const runnerStartedAtMs = Date.now();
let lastStateText = '';
let sequence = runnerStartedAtMs;

if (path) {
  clearStatus();
  const emitCurrentState = () => {
    const stateText = readText(path);
    if (stateText === lastStateText) return;
    lastStateText = stateText;
    const state = readStateText(stateText);
    if (state && (state.updatedAtMs ?? 0) >= runnerStartedAtMs) emitState(state);
  };

  watchFile(path, { interval: 100 }, emitCurrentState);
  emitCurrentState();
}

const child = spawn(process.execPath, [realScript, ...agentArgs], {
  stdio: 'inherit',
  env: process.env,
});

let childExited = false;

for (const signal of ['SIGHUP', 'SIGINT', 'SIGTERM'] as const) {
  process.on(signal, () => {
    if (!childExited) child.kill(signal);
  });
}

child.on('error', (error) => {
  if (path) unwatchFile(path);
  if (shouldEmitStatus) {
    clearStatus();
    writeInactivePaneState();
  }
  console.error(`wezterm-agent-runner: failed to start ${agent}: ${error.message}`);
  process.exit(127);
});

child.on('exit', (code, signal) => {
  childExited = true;
  if (path) unwatchFile(path);
  if (shouldEmitStatus) {
    clearStatus();
    writeInactivePaneState();
  }

  if (signal) process.exit(signalExitCode(signal));
  process.exit(code ?? 0);
});

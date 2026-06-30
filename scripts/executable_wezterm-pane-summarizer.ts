#!/usr/bin/env node
import { chmodSync, mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { execFileSync } from 'node:child_process';
import { isIP } from 'node:net';
import {
  cleanModelSummary,
  hashText,
  normalizeTerminalText,
  redactTerminalText,
  updateTerminalTaskStack,
  type PaneInfo,
  type TerminalTaskStackState,
} from './terminal-session-task-stack.ts';

interface SummaryState {
  active: boolean;
  pane: string;
  paneTty?: string;
  source: 'buffer-summary' | 'terminal-task-stack';
  summary: string;
  confidence: 'low' | 'medium' | 'high';
  sampleHash: string;
  updatedAt: string;
  updatedAtMs: number;
  summarizer: 'ollama' | 'fallback';
  taskId?: string;
}

interface PaneMemory {
  hash: string;
  stableSinceMs: number;
  summarizedHash?: string;
  lastSummaryAtMs: number;
}

const OBSERVE_INTERVAL_MS = 2_000;
const QUIET_MS = 4_000;
const REFRESH_UNCHANGED_MS = 60_000;
const MODEL_RETRY_MS = 10_000;
const SUMMARY_TTL_MS = 2 * 60 * 1000;
const RAW_HISTORY_LINES = Number(process.env.WEZTERM_PANE_SUMMARY_HISTORY_LINES ?? '1000');
const OLLAMA_MODEL = process.env.WEZTERM_PANE_SUMMARY_MODEL ?? 'qwen2.5-coder:1.5b';
const DISABLE_MODEL = process.env.WEZTERM_PANE_SUMMARY_DISABLE_MODEL === '1';

function localOllamaUrl(): string {
  const configured = process.env.WEZTERM_PANE_SUMMARY_OLLAMA_HOST ?? process.env.OLLAMA_HOST ?? 'http://127.0.0.1:11434';
  try {
    const url = new URL(configured);
    const host = url.hostname.toLowerCase();
    const ipHost = host.replace(/^\[|\]$/g, '');
    const loopback = host === 'localhost' || ipHost === '::1' || (isIP(ipHost) === 4 && ipHost.split('.')[0] === '127');
    if (!loopback) return 'http://127.0.0.1:11434';
    return url.toString().replace(/\/$/, '');
  } catch {
    return 'http://127.0.0.1:11434';
  }
}

const OLLAMA_URL = localOllamaUrl();

function runtimeRoot(name: string): string {
  const base = process.env.XDG_RUNTIME_DIR && process.env.XDG_RUNTIME_DIR !== ''
    ? process.env.XDG_RUNTIME_DIR
    : join(process.env.HOME ?? '.', '.cache');
  const root = join(base, name);
  mkdirSync(root, { recursive: true, mode: 0o700 });
  try {
    chmodSync(root, 0o700);
  } catch {
    // Best effort; the directory may be on a filesystem that ignores chmod.
  }
  return root;
}

function stateRoot(): string {
  return runtimeRoot('wezterm-pane-summary');
}

function taskStackRoot(): string {
  return runtimeRoot('wezterm-terminal-task-stack');
}

function lockDir(): string {
  return join(stateRoot(), 'daemon.lock');
}

function processExists(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

function acquireLock(): boolean {
  const dir = lockDir();
  try {
    mkdirSync(dir, { mode: 0o700 });
    writeFileSync(join(dir, 'pid'), `${process.pid}\n`, { mode: 0o600 });
    return true;
  } catch {
    try {
      const existingPid = Number(readFileSync(join(dir, 'pid'), 'utf8').trim());
      if (Number.isInteger(existingPid) && processExists(existingPid)) return false;
      rmSync(dir, { recursive: true, force: true });
      mkdirSync(dir, { mode: 0o700 });
      writeFileSync(join(dir, 'pid'), `${process.pid}\n`, { mode: 0o600 });
      return true;
    } catch {
      return false;
    }
  }
}

function releaseLock(): void {
  rmSync(lockDir(), { recursive: true, force: true });
}

function safePaneFileName(paneId: string): string {
  return `pane-${paneId.replace(/[^0-9A-Za-z_.-]/g, '_')}.json`;
}

function paneStatePath(paneId: string): string {
  return join(stateRoot(), safePaneFileName(paneId));
}

function taskStackPath(paneId: string): string {
  return join(taskStackRoot(), safePaneFileName(paneId));
}

function readJson<T>(path: string): T | undefined {
  try {
    return JSON.parse(readFileSync(path, 'utf8')) as T;
  } catch {
    return undefined;
  }
}

function writeJson(path: string, state: unknown): void {
  const temp = `${path}.${process.pid}.${Date.now()}.tmp`;
  writeFileSync(temp, `${JSON.stringify(state, null, 2)}\n`, { mode: 0o600 });
  renameSync(temp, path);
}

function readState(path: string): SummaryState | undefined {
  return readJson<SummaryState>(path);
}

function writeState(path: string, state: SummaryState): void {
  writeJson(path, state);
}

function readTaskStack(path: string): TerminalTaskStackState | undefined {
  return readJson<TerminalTaskStackState>(path);
}

function writeTaskStack(path: string, state: TerminalTaskStackState): void {
  writeJson(path, state);
}

function samePaneIdentity(state: { paneTty?: string }, pane: PaneInfo): boolean {
  return Boolean(state.paneTty && pane.tty_name && state.paneTty === pane.tty_name);
}

function renderableState(state: SummaryState | undefined, pane: PaneInfo, now = Date.now()): SummaryState | undefined {
  if (!state?.active) return undefined;
  if (state.source !== 'terminal-task-stack') return undefined;
  if (typeof state.updatedAtMs !== 'number' || now - state.updatedAtMs > SUMMARY_TTL_MS) return undefined;
  if (!samePaneIdentity(state, pane)) return undefined;
  if (state.summarizer !== 'ollama') return undefined;
  if (state.confidence !== 'medium' && state.confidence !== 'high') return undefined;
  const cleanedSummary = cleanModelSummary(state.summary);
  if (!cleanedSummary) return undefined;
  return { ...state, summary: cleanedSummary };
}

function refreshExistingState(paneId: string, safeHash: string, now: number, pane: PaneInfo): boolean {
  const path = paneStatePath(paneId);
  const state = renderableState(readState(path), pane, now);
  if (!state) return false;
  if (state.sampleHash !== safeHash) return false;

  writeState(path, {
    ...state,
    updatedAt: new Date(now).toISOString(),
    updatedAtMs: now,
  });
  return true;
}

function hasExistingRenderableState(paneId: string, pane: PaneInfo): boolean {
  return renderableState(readState(paneStatePath(paneId)), pane) !== undefined;
}

function clearState(paneId: string, pane?: PaneInfo): void {
  writeState(paneStatePath(paneId), {
    active: false,
    pane: paneId,
    paneTty: pane?.tty_name,
    source: 'terminal-task-stack',
    summary: '',
    confidence: 'low',
    sampleHash: '',
    updatedAt: new Date().toISOString(),
    updatedAtMs: Date.now(),
    summarizer: 'fallback',
  });
}

function listPanes(): PaneInfo[] {
  const output = execFileSync('wezterm', ['cli', 'list', '--format', 'json'], {
    encoding: 'utf8',
    timeout: 2_000,
    stdio: ['ignore', 'pipe', 'ignore'],
  });
  return JSON.parse(output) as PaneInfo[];
}

function getPaneText(paneId: string): string | undefined {
  try {
    return execFileSync('wezterm', ['cli', 'get-text', '--pane-id', paneId, '--start-line', `-${RAW_HISTORY_LINES}`], {
      encoding: 'utf8',
      timeout: 2_000,
      maxBuffer: 512 * 1024,
      stdio: ['ignore', 'pipe', 'ignore'],
    });
  } catch {
    return undefined;
  }
}

const seen = new Map<string, PaneMemory>();

async function observePane(pane: PaneInfo, force = false): Promise<void> {
  const paneId = String(pane.pane_id);
  const text = getPaneText(paneId);
  if (text === undefined) return;

  const normalized = normalizeTerminalText(text);
  const rawHash = hashText(normalized);
  const safeSample = redactTerminalText(normalized);
  const safeHash = hashText(safeSample);
  const prior = seen.get(paneId);
  const now = Date.now();

  if (!prior || prior.hash !== rawHash) {
    const existingState = readState(paneStatePath(paneId));
    if (existingState?.active && !samePaneIdentity(existingState, pane)) {
      seen.set(paneId, { hash: rawHash, stableSinceMs: now, lastSummaryAtMs: prior?.lastSummaryAtMs ?? 0, summarizedHash: undefined });
      clearState(paneId, pane);
      return;
    }

    if (!force && refreshExistingState(paneId, safeHash, now, pane)) {
      seen.set(paneId, { hash: rawHash, stableSinceMs: now - QUIET_MS, lastSummaryAtMs: now, summarizedHash: rawHash });
      return;
    }

    if (!force && hasExistingRenderableState(paneId, pane)) {
      seen.set(paneId, { hash: rawHash, stableSinceMs: now, lastSummaryAtMs: prior?.lastSummaryAtMs ?? 0, summarizedHash: undefined });
      return;
    }

    // No renderable model summary exists, so generate the first candidate eagerly.
    seen.set(paneId, { hash: rawHash, stableSinceMs: now - QUIET_MS, lastSummaryAtMs: prior?.lastSummaryAtMs ?? 0, summarizedHash: undefined });
  }

  const current = seen.get(paneId)!;

  if (!force) {
    if (now - current.stableSinceMs < QUIET_MS) return;
    if (current.summarizedHash !== rawHash && current.lastSummaryAtMs > 0 && now - current.lastSummaryAtMs < MODEL_RETRY_MS) return;
    if (current.summarizedHash === rawHash) {
      if (now - current.lastSummaryAtMs < REFRESH_UNCHANGED_MS) return;
      if (refreshExistingState(paneId, safeHash, now, pane)) {
        seen.set(paneId, { ...current, lastSummaryAtMs: now });
        return;
      }
      seen.set(paneId, { ...current, summarizedHash: undefined });
    }
  }

  const stackPath = taskStackPath(paneId);
  const update = await updateTerminalTaskStack({
    paneId,
    paneTitle: pane.title,
    windowTitle: pane.window_title,
    ttyName: pane.tty_name,
    text,
    observedAtMs: now,
  }, readTaskStack(stackPath), {
    model: OLLAMA_MODEL,
    ollamaUrl: OLLAMA_URL,
    disableModel: DISABLE_MODEL,
  });
  writeTaskStack(stackPath, update.state);

  if (!update.visibleSummary) {
    if (hasExistingRenderableState(paneId, pane)) {
      seen.set(paneId, { ...current, summarizedHash: undefined, lastSummaryAtMs: now });
      return;
    }

    const diagnostic = cleanModelSummary(update.diagnostic.fallbackSummary ?? '') ?? '';
    writeState(paneStatePath(paneId), {
      active: false,
      pane: paneId,
      paneTty: pane.tty_name,
      source: 'terminal-task-stack',
      summary: diagnostic,
      confidence: 'low',
      sampleHash: safeHash,
      updatedAt: new Date(now).toISOString(),
      updatedAtMs: now,
      summarizer: 'fallback',
    });
    seen.set(paneId, { ...current, summarizedHash: undefined, lastSummaryAtMs: now });
    return;
  }

  seen.set(paneId, { ...current, summarizedHash: rawHash, lastSummaryAtMs: now });
  writeState(paneStatePath(paneId), {
    active: true,
    pane: paneId,
    paneTty: pane.tty_name,
    source: 'terminal-task-stack',
    summary: update.visibleSummary.summary,
    confidence: update.visibleSummary.confidence,
    sampleHash: safeHash,
    updatedAt: new Date(now).toISOString(),
    updatedAtMs: now,
    summarizer: update.visibleSummary.summarizer,
    taskId: update.visibleSummary.taskId,
  });
}

async function once(force = false): Promise<void> {
  for (const pane of listPanes()) {
    try {
      await observePane(pane, force);
    } catch {
      // Keep other panes updating even if one pane has corrupt state or closes mid-read.
    }
  }
}

async function daemon(): Promise<void> {
  if (!acquireLock()) return;

  const cleanup = () => {
    releaseLock();
  };
  process.on('exit', cleanup);
  process.on('SIGINT', () => process.exit(0));
  process.on('SIGTERM', () => process.exit(0));

  while (true) {
    try {
      await once(false);
    } catch {
      // Keep the daemon best-effort; transient wezterm cli failures are normal
      // during reloads or while panes close.
    }
    await new Promise((resolve) => setTimeout(resolve, OBSERVE_INTERVAL_MS));
  }
}

const command = process.argv[2] ?? 'once';
if (command === 'daemon') {
  await daemon();
} else if (command === 'force-once') {
  await once(true);
} else {
  await once(false);
}

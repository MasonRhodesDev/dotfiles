#!/usr/bin/env node
import { chmodSync, closeSync, mkdirSync, openSync, readdirSync, readFileSync, readlinkSync, readSync, renameSync, rmSync, statSync, writeFileSync } from 'node:fs';
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
  source: 'buffer-summary' | 'terminal-task-stack' | 'transcript';
  summary: string;
  confidence: 'low' | 'medium' | 'high';
  sampleHash: string;
  updatedAt: string;
  updatedAtMs: number;
  summarizer: 'ollama' | 'fallback' | 'transcript';
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

function listWeztermPanes(): PaneInfo[] {
  try {
    const output = execFileSync('wezterm', ['cli', 'list', '--format', 'json'], {
      encoding: 'utf8',
      timeout: 2_000,
      stdio: ['ignore', 'pipe', 'ignore'],
    });
    return JSON.parse(output) as PaneInfo[];
  } catch {
    // wezterm not running (kitty is the daily driver); kitty panes still work.
    return [];
  }
}

// Kitty pane ids are "kitty-<kitty pid>-<window id>" — the same key the
// agent runner/bridge and tab_bar.py use (the pid disambiguates instances:
// Hyprland runs one kitty per OS window, so window ids alone collide).
// Rebuilt every listPanes() cycle; maps pane id -> remote-control target.
const kittySockets = new Map<string, { socket: string; windowId: number }>();

// Panes that look like they host an agent harness right now. Summaries are
// for harness panes only — a plain interactive shell gets none (the human
// typing there already knows what it's about).
const agentPaneHints = new Set<string>();

const AGENT_PROCESS_NAMES = new Set(['claude', 'codex', 'pi']);

function kittyWindowLooksLikeAgent(w: any): boolean {
  const uv = w?.user_vars ?? {};
  if (uv.AGENT_ACTIVE === '1' || uv.CLAUDE_ACTIVE === '1') return true;
  // Remote agent behind ssh: its title crosses the wire ("✳ …" idle, braille
  // spinner while working) even when its OSC cannot (Tailscale SSH leaves the
  // remote pty root-owned, so remote hooks can't emit).
  if (/^[✳⠀-⣿] /u.test(w?.title ?? '')) return true;
  for (const proc of w?.foreground_processes ?? []) {
    for (const arg of proc?.cmdline ?? []) {
      const base = String(arg).split('/').pop() ?? '';
      if (AGENT_PROCESS_NAMES.has(base)) return true;
    }
  }
  return false;
}

function freshAgentPaneKeys(): Set<string> {
  const keys = new Set<string>();
  const root = join(stateRoot(), '..', 'wezterm-agent-status');
  let agents: string[] = [];
  try {
    agents = readdirSync(root);
  } catch {
    return keys;
  }
  const now = Date.now();
  for (const agent of agents) {
    let files: string[] = [];
    try {
      files = readdirSync(join(root, agent));
    } catch {
      continue;
    }
    for (const file of files) {
      if (!file.startsWith('pane-') || !file.endsWith('.json')) continue;
      try {
        const state = JSON.parse(readFileSync(join(root, agent, file), 'utf8'));
        if (state?.active && typeof state.updatedAtMs === 'number' && now - state.updatedAtMs <= SUMMARY_TTL_MS && state.pane) {
          keys.add(String(state.pane));
        }
      } catch {
        continue;
      }
    }
  }
  return keys;
}

function listKittyPanes(): PaneInfo[] {
  kittySockets.clear();
  agentPaneHints.clear();
  let pids: string[] = [];
  try {
    pids = execFileSync('pgrep', ['-x', 'kitty'], { encoding: 'utf8', timeout: 2_000 })
      .split('\n').map((s) => s.trim()).filter(Boolean);
  } catch {
    return [];
  }
  const panes: PaneInfo[] = [];
  for (const pid of pids) {
    const socket = `unix:@kitty-${pid}`;
    let listing: any;
    try {
      listing = JSON.parse(execFileSync('kitten', ['@', '--to', socket, 'ls'], {
        encoding: 'utf8',
        timeout: 2_000,
        maxBuffer: 4 * 1024 * 1024,
        stdio: ['ignore', 'pipe', 'ignore'],
      }));
    } catch {
      continue;
    }
    for (const osWindow of listing ?? []) {
      for (const tab of osWindow.tabs ?? []) {
        for (const w of tab.windows ?? []) {
          const paneId = `kitty-${pid}-${w.id}`;
          let tty: string | undefined;
          try {
            tty = readlinkSync(`/proc/${w.pid}/fd/0`);
          } catch {
            // Shell already gone or unreadable; pane still summarizable.
          }
          kittySockets.set(paneId, { socket, windowId: w.id });
          if (kittyWindowLooksLikeAgent(w)) agentPaneHints.add(paneId);
          panes.push({ pane_id: paneId, title: w.title, window_title: w.title, tty_name: tty });
        }
      }
    }
  }
  return panes;
}

function listPanes(): PaneInfo[] {
  return [...listWeztermPanes(), ...listKittyPanes()];
}

function getPaneText(paneId: string): string | undefined {
  const kitty = kittySockets.get(paneId);
  if (kitty) {
    try {
      const text = execFileSync('kitten', ['@', '--to', kitty.socket, 'get-text', '--match', `id:${kitty.windowId}`, '--extent', 'all'], {
        encoding: 'utf8',
        timeout: 2_000,
        maxBuffer: 8 * 1024 * 1024,
        stdio: ['ignore', 'pipe', 'ignore'],
      });
      const lines = text.split('\n');
      return lines.slice(Math.max(0, lines.length - RAW_HISTORY_LINES)).join('\n');
    } catch {
      return undefined;
    }
  }
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

// --- Transcript mode -------------------------------------------------------
// Claude Code panes get their summary from the session transcript instead of
// scrollback: richer signal and zero model cost. The SessionStart hook writes
// /tmp/claude-wezterm/<session>.pane with TTY_DEVICE and SESSION_FILE; match
// panes by tty. Codex/other panes stay on the scrollback pipeline.

const CLAUDE_CORRELATION_DIR = '/tmp/claude-wezterm';
const TRANSCRIPT_TAIL_BYTES = 256 * 1024;
const TRANSCRIPT_HEAD_BYTES = 64 * 1024;
const TRANSCRIPT_RESTAMP_MS = 60_000;

function ttyToTranscript(): Map<string, string> {
  const map = new Map<string, string>();
  let entries: string[] = [];
  try {
    entries = readdirSync(CLAUDE_CORRELATION_DIR);
  } catch {
    return map;
  }
  for (const entry of entries) {
    if (!entry.endsWith('.pane')) continue;
    try {
      const content = readFileSync(join(CLAUDE_CORRELATION_DIR, entry), 'utf8');
      const tty = content.match(/^TTY_DEVICE=(.+)$/m)?.[1]?.trim();
      const transcript = content.match(/^SESSION_FILE=(.+)$/m)?.[1]?.trim();
      if (tty && transcript && existsSyncSafe(transcript)) map.set(tty, transcript);
    } catch {
      // Correlation file mid-write or removed; skip.
    }
  }
  return map;
}

function existsSyncSafe(path: string): boolean {
  try {
    statSync(path);
    return true;
  } catch {
    return false;
  }
}

function readFileSlice(path: string, position: number, length: number): string {
  const fd = openSync(path, 'r');
  try {
    const buffer = Buffer.alloc(length);
    const bytes = readSync(fd, buffer, 0, length, position);
    return buffer.subarray(0, bytes).toString('utf8');
  } finally {
    closeSync(fd);
  }
}

function firstTextContent(message: any): string | undefined {
  const content = message?.content;
  if (typeof content === 'string') return content;
  if (Array.isArray(content)) {
    for (const item of content) {
      if (item?.type === 'text' && typeof item.text === 'string') return item.text;
    }
  }
  return undefined;
}

function usableUserText(text: string | undefined): string | undefined {
  if (!text) return undefined;
  const cleaned = text.replace(/\s+/g, ' ').trim();
  if (!cleaned) return undefined;
  // Skip harness noise: system reminders, slash commands, caveat banners.
  if (cleaned.startsWith('<') || cleaned.startsWith('/') || cleaned.startsWith('Caveat:')) return undefined;
  return cleaned;
}

function transcriptGist(path: string): { summary: string; confidence: 'medium' | 'high' } | undefined {
  let size: number;
  try {
    size = statSync(path).size;
  } catch {
    return undefined;
  }

  // Newest compaction/title summary wins (scan the tail backwards).
  try {
    const tail = readFileSlice(path, Math.max(0, size - TRANSCRIPT_TAIL_BYTES), Math.min(size, TRANSCRIPT_TAIL_BYTES));
    const lines = tail.split('\n');
    for (let i = lines.length - 1; i >= 0; i--) {
      const line = lines[i].trim();
      if (!line.includes('"summary"')) continue;
      try {
        const parsed = JSON.parse(line);
        if (parsed?.type === 'summary' && typeof parsed.summary === 'string' && parsed.summary.trim()) {
          return { summary: parsed.summary.trim(), confidence: 'high' };
        }
      } catch {
        // Partial line at the slice boundary; keep scanning.
      }
    }
  } catch {
    // Fall through to the head scan.
  }

  // Otherwise: the first real user prompt is what the conversation is about.
  try {
    const head = readFileSlice(path, 0, Math.min(size, TRANSCRIPT_HEAD_BYTES));
    for (const rawLine of head.split('\n')) {
      const line = rawLine.trim();
      if (!line) continue;
      try {
        const parsed = JSON.parse(line);
        if (parsed?.type !== 'user') continue;
        const text = usableUserText(firstTextContent(parsed.message));
        if (text) return { summary: text, confidence: 'medium' };
      } catch {
        continue;
      }
    }
  } catch {
    return undefined;
  }
  return undefined;
}

const TAGLINE_MAX_CHARS = 60;

function taglineOf(text: string): string {
  const compact = text.replace(/\s+/g, ' ').trim();
  const sentence = compact.split(/(?<=[.!?])\s/)[0] ?? compact;
  let out = sentence;
  if (out.length > TAGLINE_MAX_CHARS) {
    out = out.slice(0, TAGLINE_MAX_CHARS);
    const lastSpace = out.lastIndexOf(' ');
    if (lastSpace > 20) out = out.slice(0, lastSpace);
    out = `${out.trimEnd()}…`;
  }
  return out.replace(/[.,;:\s]+$/, '');
}

interface TranscriptMemory {
  mtimeMs: number;
  size: number;
  lastWriteMs: number;
}

const transcriptSeen = new Map<string, TranscriptMemory>();

function observeTranscriptPane(pane: PaneInfo, transcript: string): boolean {
  const paneId = String(pane.pane_id);
  let stat;
  try {
    stat = statSync(transcript);
  } catch {
    return false;
  }
  const now = Date.now();
  const prior = transcriptSeen.get(paneId);
  const unchanged = prior && prior.mtimeMs === stat.mtimeMs && prior.size === stat.size;
  if (unchanged && now - prior.lastWriteMs < TRANSCRIPT_RESTAMP_MS) return true;

  const gist = transcriptGist(transcript);
  if (!gist) return false;

  // Transcript text is not model output — cleanModelSummary would mangle it.
  // Redact, then compress to a tagline: first sentence, word-boundary
  // truncated. Headers want an article title, not a paragraph.
  const summary = taglineOf(redactTerminalText(gist.summary));
  if (!summary) return false;

  transcriptSeen.set(paneId, { mtimeMs: stat.mtimeMs, size: stat.size, lastWriteMs: now });
  writeState(paneStatePath(paneId), {
    active: true,
    pane: paneId,
    paneTty: pane.tty_name,
    source: 'transcript',
    summary,
    confidence: gist.confidence,
    sampleHash: hashText(`${transcript}:${stat.mtimeMs}:${stat.size}`),
    updatedAt: new Date(now).toISOString(),
    updatedAtMs: now,
    summarizer: 'transcript',
  });
  return true;
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
  const transcripts = ttyToTranscript();
  const panes = listPanes();
  const agentKeys = freshAgentPaneKeys();
  for (const pane of panes) {
    try {
      const paneId = String(pane.pane_id);
      const transcript = pane.tty_name ? transcripts.get(pane.tty_name) : undefined;
      if (transcript && observeTranscriptPane(pane, transcript)) continue;

      // Summaries are for harness panes only. A pane qualifies via a fresh
      // agent state file, a kitty-side hint (user vars / foreground agent
      // process), or a claude transcript correlation. Anything else is a
      // manual terminal: skip it, and clear any summary left from an agent
      // that has since exited.
      if (!agentKeys.has(paneId) && !agentPaneHints.has(paneId)) {
        const existing = readState(paneStatePath(paneId));
        if (existing?.active) clearState(paneId, pane);
        continue;
      }
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

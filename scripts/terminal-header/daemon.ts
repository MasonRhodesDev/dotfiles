#!/usr/bin/env node
// Terminal header daemon: snapshots every kitty window and wezterm pane,
// runs each through the section resolver, and writes
//   $XDG_RUNTIME_DIR/terminal-header/pane-<key>.json  { header, updatedAtMs }
// Terminals are dumb renderers of that file. Inputs (user vars, agent state
// files, claude correlation, pane summaries) are produced elsewhere — by the
// claude hooks, agent runner/bridge, and pane-summarizer.service.

import {
  chmodSync, mkdirSync, readdirSync, readFileSync,
  renameSync, rmSync, statSync, writeFileSync,
} from 'node:fs';
import { join } from 'node:path';
import type { AgentState, SectionContext } from './types.ts';
import { resolveHeader } from './resolver.ts';
import { TARGETS } from './targets/index.ts';

const TICK_MS = 1_500;
const AGENT_STATE_TTL_MS = 2 * 60 * 1000;
const SUMMARY_TTL_MS = 2 * 60 * 1000;
const SUMMARY_MAX_CHARS = 48;
const RESTAMP_MS = 20_000;
const CLAUDE_CORRELATION_DIR = '/tmp/claude-wezterm';

function runtimeRoot(name: string): string {
  const base = process.env.XDG_RUNTIME_DIR && process.env.XDG_RUNTIME_DIR !== ''
    ? process.env.XDG_RUNTIME_DIR
    : join(process.env.HOME ?? '.', '.cache');
  const root = join(base, name);
  mkdirSync(root, { recursive: true, mode: 0o700 });
  try {
    chmodSync(root, 0o700);
  } catch {
    // Filesystem may ignore chmod; best effort.
  }
  return root;
}

function safeName(value: string): string {
  return value.replace(/[^a-zA-Z0-9_.-]/g, '_');
}

function headerPath(paneKey: string): string {
  return join(runtimeRoot('terminal-header'), `pane-${safeName(paneKey)}.json`);
}

function readJson(path: string): any {
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch {
    return undefined;
  }
}

function writeJson(path: string, value: unknown): void {
  const temp = `${path}.${process.pid}.tmp`;
  writeFileSync(temp, `${JSON.stringify(value)}\n`, { mode: 0o600 });
  renameSync(temp, path);
}

// --- Section context --------------------------------------------------------

function loadAgentStates(nowMs: number): Map<string, AgentState> {
  const map = new Map<string, AgentState>();
  const root = runtimeRoot('wezterm-agent-status');
  let agents: string[] = [];
  try {
    agents = readdirSync(root);
  } catch {
    return map;
  }
  for (const agent of agents) {
    if (!['claude', 'codex', 'pi'].includes(agent)) continue;
    let files: string[] = [];
    try {
      files = readdirSync(join(root, agent));
    } catch {
      continue;
    }
    for (const file of files) {
      if (!file.startsWith('pane-') || !file.endsWith('.json')) continue;
      const state = readJson(join(root, agent, file));
      if (!state?.active || typeof state.updatedAtMs !== 'number') continue;
      if (nowMs - state.updatedAtMs > AGENT_STATE_TTL_MS) continue;
      if (!state.pane) continue;
      const key = String(state.pane);
      const existing = map.get(key);
      if (!existing || state.updatedAtMs > existing.updatedAtMs) {
        map.set(key, { agent, model: state.model ?? '', state: state.state ?? '', updatedAtMs: state.updatedAtMs });
      }
    }
  }
  return map;
}

function loadTranscripts(): Map<string, string> {
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
      if (tty && transcript) {
        try {
          statSync(transcript);
          map.set(tty, transcript);
        } catch {
          // Transcript removed; ignore stale correlation.
        }
      }
    } catch {
      continue;
    }
  }
  return map;
}

// Display gate: a summary renders only if it reads like a tagline. Model
// output gets the strict treatment (ports the old wezterm safe_summary
// heuristics — small local models emit lists, paths, and quoted fragments);
// transcript-sourced compaction titles are already title-shaped and only get
// the length treatment. Anything rejected simply doesn't render — a missing
// tagline beats a dirty one.
function saneTagline(raw: string, summarizer: string): string | undefined {
  let s = raw.replace(/["'`]/g, '').replace(/\s+/g, ' ').trim();
  if (!s || s.includes('[REDACTED')) return undefined;
  if (summarizer !== 'transcript') {
    if (s.split(' ').length > 8) return undefined;
    if (/[,;{}\[\]<>|=]/.test(s)) return undefined;
    if (/https?:\/\//i.test(s) || /\S+@\S+\.\S+/.test(s)) return undefined;
    if (/[0-9a-f]{16,}/i.test(s)) return undefined;
    if (/\S+\/\S+/.test(s)) return undefined;
  }
  if (s.length > SUMMARY_MAX_CHARS) {
    s = s.slice(0, SUMMARY_MAX_CHARS);
    const lastSpace = s.lastIndexOf(' ');
    if (lastSpace > 20) s = s.slice(0, lastSpace);
    s = `${s.trimEnd()}…`;
  }
  return s.replace(/[.,;:\s]+$/, '') || undefined;
}

function loadSummary(paneKey: string, nowMs: number): string | undefined {
  const state = readJson(join(runtimeRoot('wezterm-pane-summary'), `pane-${safeName(paneKey)}.json`));
  if (!state?.active) return undefined;
  if (typeof state.updatedAtMs !== 'number' || nowMs - state.updatedAtMs > SUMMARY_TTL_MS) return undefined;
  if (state.confidence !== 'medium' && state.confidence !== 'high') return undefined;
  if (typeof state.summary !== 'string') return undefined;
  return saneTagline(state.summary, String(state.summarizer ?? ''));
}

// --- Main loop ---------------------------------------------------------------

const lastWritten = new Map<string, { header: string | null; atMs: number }>();

function tick(): void {
  const nowMs = Date.now();
  const agentStates = loadAgentStates(nowMs);
  const transcripts = loadTranscripts();
  const ctx: SectionContext = {
    nowMs,
    agentState: (paneKey) => agentStates.get(paneKey),
    transcriptForTty: (tty) => (tty ? transcripts.get(tty) : undefined),
    summary: (paneKey) => loadSummary(paneKey, nowMs),
    fired: new Set(),
  };

  const seen = new Set<string>();
  const snapshots = TARGETS.filter((t) => t.available()).flatMap((t) => {
    try {
      return t.listPanes();
    } catch {
      // One broken target must not take down the others.
      return [];
    }
  });
  for (const snapshot of snapshots) {
    seen.add(snapshot.paneKey);
    let header: string | null = null;
    try {
      header = resolveHeader(snapshot, ctx);
    } catch {
      header = null;
    }
    const prev = lastWritten.get(snapshot.paneKey);
    if (prev && prev.header === header && nowMs - prev.atMs < RESTAMP_MS) continue;
    writeJson(headerPath(snapshot.paneKey), { header, updatedAtMs: nowMs });
    lastWritten.set(snapshot.paneKey, { header, atMs: nowMs });
  }

  // Drop output files for panes that no longer exist.
  for (const key of lastWritten.keys()) {
    if (!seen.has(key)) {
      try {
        rmSync(headerPath(key), { force: true });
      } catch {
        // Best effort.
      }
      lastWritten.delete(key);
    }
  }
}

const command = process.argv[2] ?? 'daemon';
if (command === 'once') {
  tick();
} else {
  process.on('SIGINT', () => process.exit(0));
  process.on('SIGTERM', () => process.exit(0));
  while (true) {
    try {
      tick();
    } catch {
      // Transient terminal-CLI failures during reloads are normal.
    }
    await new Promise((resolve) => setTimeout(resolve, TICK_MS));
  }
}

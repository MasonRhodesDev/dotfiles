#!/usr/bin/env node
// Table-driven resolver tests: PaneSnapshot + fake context in, header out.
// Run: node ~/scripts/terminal-header/test.ts

import type { AgentState, PaneSnapshot, SectionContext } from './types.ts';
import { resolveHeader } from './resolver.ts';

interface Case {
  name: string;
  snapshot: Partial<PaneSnapshot>;
  agentStates?: Record<string, AgentState>;
  transcripts?: Record<string, string>;
  summaries?: Record<string, string>;
  want: string | null;
}

const HOME = process.env.HOME ?? '';
const NOW = 1_784_000_000_000;

function proc(cmdline: string[], cwd?: string) {
  return { pid: 1, cmdline, cwd };
}

const CASES: Case[] = [
  {
    name: 'plain shell has no header',
    snapshot: { foregroundProcesses: [proc(['fish'])] },
    want: null,
  },
  {
    name: 'plain shell with summary present still has no header',
    snapshot: { paneKey: 'kitty-1-1', foregroundProcesses: [proc(['fish'])] },
    summaries: { 'kitty-1-1': 'doing things' },
    want: null,
  },
  {
    name: 'ssh shows destination host',
    snapshot: { foregroundProcesses: [proc(['ssh', '-p', '2222', 'mason@work-horse'])] },
    want: '🔐 work-horse',
  },
  {
    name: 'claude via user vars: agent + cwd + summary',
    snapshot: {
      paneKey: 'kitty-1-1',
      userVars: { CLAUDE_ACTIVE: '1', CLAUDE_MODEL: 'claude-fable-5[1m]' },
      foregroundProcesses: [proc([`${HOME}/.local/bin/claude`], `${HOME}/repos/hypr`)],
    },
    summaries: { 'kitty-1-1': 'Reviewing header project' },
    want: '🤖 Claude (fable) | 📁 ~/repos/hypr | Reviewing header project',
  },
  {
    name: 'stale CLAUDE_ACTIVE at a bare shell is suppressed',
    snapshot: {
      userVars: { CLAUDE_ACTIVE: '1', CLAUDE_MODEL: 'claude-fable-5' },
      foregroundProcesses: [proc(['fish'])],
    },
    want: null,
  },
  {
    name: 'codex via state file only (no user vars)',
    snapshot: {
      paneKey: 'kitty-2-1',
      foregroundProcesses: [proc(['node', '/x/codex.js'], `${HOME}/repos/odin-data-model`)],
    },
    agentStates: { 'kitty-2-1': { agent: 'codex', model: 'gpt-5.6-sol', updatedAtMs: NOW } },
    want: '✦ Codex (gpt-5.6-sol) | 📁 ~/repos/odin-data-model',
  },
  {
    name: 'remote claude over ssh: host + agent, no local cwd',
    snapshot: {
      paneKey: 'kitty-3-1',
      userVars: { CLAUDE_ACTIVE: '1', CLAUDE_MODEL: 'claude-opus-4-8' },
      foregroundProcesses: [proc(['ssh', 'mason-work-horse'], `${HOME}`)],
    },
    summaries: { 'kitty-3-1': 'remote scrollback tagline' },
    want: '🔐 mason-work-horse | 🤖 Claude (opus) | remote scrollback tagline',
  },
  {
    name: 'cleared agent vars mean no header',
    snapshot: {
      userVars: { AGENT_ACTIVE: '0', CLAUDE_ACTIVE: '0' },
      foregroundProcesses: [proc(['top'])],
    },
    want: null,
  },
  {
    name: 'wezterm claude via transcript correlation (no vars, no state file)',
    snapshot: {
      paneKey: '42',
      terminal: 'wezterm',
      tty: '/dev/pts/9',
      foregroundProcesses: [proc([`${HOME}/.local/bin/claude`], `${HOME}`)],
    },
    transcripts: { '/dev/pts/9': '/some/transcript.jsonl' },
    want: '🤖 Claude | 📁 ~',
  },
  {
    name: 'runner-driven agent vars with kind',
    snapshot: {
      paneKey: 'kitty-4-1',
      userVars: { AGENT_ACTIVE: '1', AGENT_KIND: '2' },
      foregroundProcesses: [proc(['node', '/x/codex.js'])],
    },
    agentStates: { 'kitty-4-1': { agent: 'codex', model: 'gpt-5.6-terra', updatedAtMs: NOW } },
    want: '✦ Codex (gpt-5.6-terra)',
  },
  {
    name: 'long cwd is tail-truncated',
    snapshot: {
      paneKey: 'kitty-5-1',
      userVars: { CLAUDE_ACTIVE: '1' },
      foregroundProcesses: [proc(['claude'], `${HOME}/repos/some-very-long-project-name/deep/nested/dir`)],
    },
    want: '🤖 Claude | 📁 …/deep/nested/dir',
  },
];

let failures = 0;
for (const c of CASES) {
  const snapshot: PaneSnapshot = {
    paneKey: 'kitty-0-0',
    terminal: 'kitty',
    userVars: {},
    foregroundProcesses: [],
    ...c.snapshot,
  };
  const ctx: SectionContext = {
    nowMs: NOW,
    agentState: (k) => c.agentStates?.[k],
    transcriptForTty: (t) => (t ? c.transcripts?.[t] : undefined),
    summary: (k) => c.summaries?.[k],
    fired: new Set(),
  };
  const got = resolveHeader(snapshot, ctx);
  if (got === c.want) {
    console.log(`✓ ${c.name}`);
  } else {
    failures++;
    console.log(`✗ ${c.name}\n    got:  ${JSON.stringify(got)}\n    want: ${JSON.stringify(c.want)}`);
  }
}

console.log(`\n${CASES.length - failures}/${CASES.length} resolver cases passed`);
if (failures) process.exit(1);

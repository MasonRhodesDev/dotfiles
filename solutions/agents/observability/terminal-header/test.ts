#!/usr/bin/env node

import type { AgentState, PaneSnapshot, SectionContext } from './src/types.ts';
import { resolveHeader } from './src/resolver.ts';

interface Case {
  name: string;
  snapshot: Partial<PaneSnapshot>;
  agentStates?: Record<string, AgentState>;
  transcripts?: Record<string, string>;
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
    name: 'ssh shows destination host',
    snapshot: { foregroundProcesses: [proc(['ssh', '-p', '2222', 'user@build-box'])] },
    want: '🔐 build-box',
  },
  {
    name: 'claude via user vars: agent + cwd',
    snapshot: {
      paneKey: 'kitty-1-1',
      userVars: { CLAUDE_ACTIVE: '1', CLAUDE_MODEL: 'claude-fable-5[1m]' },
      foregroundProcesses: [proc([`${HOME}/.local/bin/claude`], `${HOME}/repos/hypr`)],
    },
    want: '🤖 Claude (fable) | 📁 ~/repos/hypr',
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
      foregroundProcesses: [proc(['node', '/x/codex.js'], `${HOME}/repos/example-repo`)],
    },
    agentStates: { 'kitty-2-1': { agent: 'codex', model: 'gpt-5.6-sol', updatedAtMs: NOW } },
    want: '✦ Codex (gpt-5.6-sol) | 📁 ~/repos/example-repo',
  },
  {
    name: 'remote claude over ssh: host + agent, no local cwd',
    snapshot: {
      paneKey: 'kitty-3-1',
      userVars: { CLAUDE_ACTIVE: '1', CLAUDE_MODEL: 'claude-opus-4-8' },
      foregroundProcesses: [proc(['ssh', 'build-host'], `${HOME}`)],
    },
    want: '🔐 build-host | 🤖 Claude (opus)',
  },
  {
    name: 'remote claude behind tailscale ssh detected by title',
    snapshot: {
      paneKey: 'kitty-6-1',
      title: '✳ Claude Code',
      foregroundProcesses: [proc(['ssh', 'build-host'], HOME)],
    },
    want: '🔐 build-host | 🤖 Claude',
  },
  {
    name: 'remote claude title with spinner glyph and stale local vars',
    snapshot: {
      title: '⠐ fixing the header daemon',
      userVars: { CLAUDE_ACTIVE: '0' },
      foregroundProcesses: [proc(['ssh', 'build-box'])],
    },
    want: '🔐 build-box | 🤖 Claude',
  },
  {
    name: 'ssh without an agent title is just ssh',
    snapshot: {
      title: 'user@build-host:~',
      foregroundProcesses: [proc(['ssh', 'build-host'])],
    },
    want: '🔐 build-host',
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
    name: 'claude via transcript correlation (no vars, no state file)',
    snapshot: {
      paneKey: 'kitty-6-1',
      terminal: 'kitty',
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

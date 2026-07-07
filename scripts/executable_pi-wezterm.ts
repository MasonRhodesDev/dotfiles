#!/usr/bin/env node
import { spawn } from 'node:child_process';

const RUNNER = '/home/mason/scripts/wezterm-agent-runner.ts';
const REAL_PI = '/home/mason/.local/lib/node_modules/@earendil-works/pi-coding-agent/dist/cli.js';

// WEZTERM_PANE (wezterm) or KITTY_WINDOW_ID (kitty) — the runner resolves
// the pane identity itself and emits the same OSC user-var protocol to both.
const inSupportedTerminal = Boolean(process.env.WEZTERM_PANE || process.env.KITTY_WINDOW_ID);
const shouldUseWeztermRunner = Boolean(inSupportedTerminal && process.stdout.isTTY);
const args = shouldUseWeztermRunner
  ? [RUNNER, 'pi', REAL_PI, ...process.argv.slice(2)]
  : [REAL_PI, ...process.argv.slice(2)];

const child = spawn(process.execPath, args, { stdio: 'inherit', env: process.env });
child.on('exit', (code, signal) => {
  if (signal) {
    process.kill(process.pid, signal);
    return;
  }
  process.exit(code ?? 0);
});
child.on('error', (error) => {
  console.error(`pi-wezterm: failed to start pi: ${error.message}`);
  process.exit(127);
});

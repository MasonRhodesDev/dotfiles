#!/usr/bin/env node
import { spawn } from 'node:child_process';

const RUNNER = '@home@/scripts/agent-status-runner.ts';
const REAL_CODEX = '@home@/.npm-global/lib/node_modules/@openai/codex/bin/codex.js';

const inSupportedTerminal = Boolean(process.env.KITTY_WINDOW_ID || (process.env.TERM ?? '').includes('kitty'));
const useRunner = Boolean(inSupportedTerminal && process.stdout.isTTY);
const args = useRunner
  ? [RUNNER, 'codex', REAL_CODEX, ...process.argv.slice(2)]
  : [REAL_CODEX, ...process.argv.slice(2)];

const child = spawn(process.execPath, args, { stdio: 'inherit', env: process.env });
child.on('exit', (code, signal) => {
  if (signal) {
    process.kill(process.pid, signal);
    return;
  }
  process.exit(code ?? 0);
});
child.on('error', (error) => {
  console.error(`agent-status-codex: failed to start Codex: ${error.message}`);
  process.exit(127);
});

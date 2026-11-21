import { execFileSync } from 'node:child_process';
import { readlinkSync } from 'node:fs';
import type { ForegroundProcess, PaneSnapshot, TerminalTarget } from '../types.ts';
import { binaryOnPath } from './util.ts';

let known: boolean | undefined;

export const kittyTarget: TerminalTarget = {
  name: 'kitty',

  available(): boolean {
    if (known === undefined) known = binaryOnPath('kitten');
    return known;
  },

  listPanes(): PaneSnapshot[] {
    let pids: string[] = [];
    try {
      pids = execFileSync('pgrep', ['-x', 'kitty'], { encoding: 'utf8', timeout: 2_000 })
        .split('\n').map((s) => s.trim()).filter(Boolean);
    } catch {
      return [];
    }
    const snapshots: PaneSnapshot[] = [];
    for (const pid of pids) {
      let listing: any;
      try {
        listing = JSON.parse(execFileSync('kitten', ['@', '--to', `unix:@kitty-${pid}`, 'ls'], {
          encoding: 'utf8', timeout: 2_000, maxBuffer: 4 * 1024 * 1024, stdio: ['ignore', 'pipe', 'ignore'],
        }));
      } catch {
        continue;
      }
      for (const osWindow of listing ?? []) {
        for (const tab of osWindow.tabs ?? []) {
          for (const w of tab.windows ?? []) {
            let tty: string | undefined;
            try {
              tty = readlinkSync(`/proc/${w.pid}/fd/0`);
            } catch {
            }
            snapshots.push({
              paneKey: `kitty-${pid}-${w.id}`,
              terminal: 'kitty',
              tty,
              title: w.title,
              userVars: w.user_vars ?? {},
              foregroundProcesses: (w.foreground_processes ?? []).map((p: any): ForegroundProcess => ({
                pid: p.pid, cmdline: p.cmdline ?? [], cwd: p.cwd,
              })),
            });
          }
        }
      }
    }
    return snapshots;
  },
};

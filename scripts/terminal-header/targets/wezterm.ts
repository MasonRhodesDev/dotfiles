import { execFileSync } from 'node:child_process';
import type { ForegroundProcess, PaneSnapshot, TerminalTarget } from '../types.ts';
import { binaryOnPath } from './util.ts';

// wezterm's CLI exposes neither user vars nor foreground processes: panes
// come from `wezterm cli list` and the process list is recovered per tty
// from one ps sweep. Pane keys are wezterm's numeric pane ids.

let known: boolean | undefined;

function processesByTty(): Map<string, ForegroundProcess[]> {
  const byTty = new Map<string, ForegroundProcess[]>();
  try {
    const out = execFileSync('ps', ['-eo', 'tty=,pid=,args='], {
      encoding: 'utf8', timeout: 2_000, maxBuffer: 4 * 1024 * 1024,
    });
    for (const line of out.split('\n')) {
      const m = line.match(/^\s*(pts\/\d+)\s+(\d+)\s+(.+)$/);
      if (!m) continue;
      const tty = `/dev/${m[1]}`;
      const list = byTty.get(tty) ?? [];
      list.push({ pid: Number(m[2]), cmdline: m[3].split(/\s+/) });
      byTty.set(tty, list);
    }
  } catch {
    // ps failure: wezterm panes just get fewer sections this tick.
  }
  return byTty;
}

export const weztermTarget: TerminalTarget = {
  name: 'wezterm',

  available(): boolean {
    if (known === undefined) known = binaryOnPath('wezterm');
    return known;
  },

  listPanes(): PaneSnapshot[] {
    let panes: any[];
    try {
      panes = JSON.parse(execFileSync('wezterm', ['cli', 'list', '--format', 'json'], {
        encoding: 'utf8', timeout: 2_000, stdio: ['ignore', 'pipe', 'ignore'],
      }));
    } catch {
      // Installed but not running.
      return [];
    }
    const byTty = processesByTty();
    return panes.map((p: any): PaneSnapshot => ({
      paneKey: String(p.pane_id),
      terminal: 'wezterm',
      tty: p.tty_name,
      title: p.title,
      userVars: {},
      foregroundProcesses: p.tty_name ? (byTty.get(p.tty_name) ?? []) : [],
    }));
  },
};

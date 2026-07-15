import type { PaneSnapshot, Section, SectionContext } from '../types.ts';

// ssh options that consume the next argument (from ssh(1)) — needed to find
// the first non-option word, the destination.
const OPTS_WITH_ARG = new Set('BbcDEeFIiJLlmOoPpRSWw'.split(''));

export function sshDestination(cmdline: string[]): string | undefined {
  const args = cmdline.slice(1);
  let dest: string | undefined;
  for (let i = 0; i < args.length; ) {
    const a = args[i];
    if (a === '--') {
      dest = args[i + 1];
      break;
    }
    if (a.startsWith('-') && a.length > 1) {
      i += a.length === 2 && OPTS_WITH_ARG.has(a[1]) ? 2 : 1;
      continue;
    }
    dest = a;
    break;
  }
  if (!dest) return undefined;
  if (dest.startsWith('ssh://')) {
    dest = dest.slice('ssh://'.length).split('/', 1)[0].replace(/:\d+$/, '');
  }
  const at = dest.lastIndexOf('@');
  if (at >= 0) dest = dest.slice(at + 1);
  return dest || undefined;
}

export const sshSection: Section = {
  name: 'ssh',
  tier: 0,
  detect(snapshot: PaneSnapshot, ctx: SectionContext): string | null {
    for (const proc of snapshot.foregroundProcesses) {
      const argv0 = proc.cmdline[0] ?? '';
      if ((argv0.split('/').pop() ?? '') === 'ssh') {
        const host = sshDestination(proc.cmdline);
        return host ? `🔐 ${host}` : '🔐 SSH';
      }
    }
    return null;
  },
};

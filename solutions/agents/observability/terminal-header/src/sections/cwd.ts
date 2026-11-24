import type { PaneSnapshot, Section, SectionContext } from '../types.ts';

const CWD_MAX_CHARS = 40;

export function abbreviatePath(path: string, home: string): string {
  if (path === home) return '~';
  if (path.startsWith(`${home}/`)) path = `~${path.slice(home.length)}`;
  if (path.length > CWD_MAX_CHARS) {
    const parts = path.split('/');
    while (parts.length > 2 && `…/${parts.join('/')}`.length > CWD_MAX_CHARS) {
      parts.shift();
    }
    path = `…/${parts.join('/')}`;
  }
  return path;
}

export const cwdSection: Section = {
  name: 'cwd',
  tier: 20,
  detect(snapshot: PaneSnapshot, ctx: SectionContext): string | null {
    if (!ctx.fired.has('agent') || ctx.fired.has('ssh')) return null;
    const cwd = snapshot.foregroundProcesses[0]?.cwd;
    if (!cwd) return null;
    return `📁 ${abbreviatePath(cwd, process.env.HOME ?? '')}`;
  },
};

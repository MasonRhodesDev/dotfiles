import type { PaneSnapshot, Section, SectionContext } from './types.ts';
import { sshSection } from './sections/ssh.ts';
import { agentSection } from './sections/agent.ts';
import { cwdSection } from './sections/cwd.ts';

export const SECTIONS: Section[] = [
  sshSection,
  agentSection,
  cwdSection,
].sort((a, b) => a.tier - b.tier);

export const SEPARATOR = ' | ';

export function resolveHeader(snapshot: PaneSnapshot, ctx: SectionContext): string | null {
  const parts: string[] = [];
  ctx.fired.clear();
  for (const section of SECTIONS) {
    let text: string | null = null;
    try {
      text = section.detect(snapshot, ctx);
    } catch {
    }
    if (text) {
      parts.push(text);
      ctx.fired.add(section.name);
    }
  }
  return parts.length ? parts.join(SEPARATOR) : null;
}

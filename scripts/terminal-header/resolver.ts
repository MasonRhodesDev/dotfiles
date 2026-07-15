// Pure header resolution: PaneSnapshot in, header string (or null) out.
// Sections are a tiered registry, oh-my-posh style: to add a header section,
// write a file in sections/ and register it here — nothing else changes.

import type { PaneSnapshot, Section, SectionContext } from './types.ts';
import { sshSection } from './sections/ssh.ts';
import { agentSection } from './sections/agent.ts';
import { cwdSection } from './sections/cwd.ts';
import { summarySection } from './sections/summary.ts';

export const SECTIONS: Section[] = [
  sshSection,
  agentSection,
  cwdSection,
  summarySection,
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
      // A broken section must never take the whole header down.
    }
    if (text) {
      parts.push(text);
      ctx.fired.add(section.name);
    }
  }
  return parts.length ? parts.join(SEPARATOR) : null;
}

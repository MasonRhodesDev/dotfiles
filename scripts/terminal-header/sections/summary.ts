import type { PaneSnapshot, Section, SectionContext } from '../types.ts';

export const summarySection: Section = {
  name: 'summary',
  tier: 30,
  detect(snapshot: PaneSnapshot, ctx: SectionContext): string | null {
    // Harness panes only — same reasoning as cwd: the human typing in a
    // plain terminal already knows what it's about.
    if (!ctx.fired.has('agent')) return null;
    return ctx.summary(snapshot.paneKey) ?? null;
  },
};

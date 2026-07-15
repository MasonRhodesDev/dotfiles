// Standardized input/output contract for the terminal header resolver.
//
// Input: a PaneSnapshot — everything observable about one terminal pane.
// Output: a header string with all sections pre-joined, or null (no header).
// Policy lives ONLY in sections/ + resolver.ts; terminals just draw the string.

export interface ForegroundProcess {
  pid: number;
  cmdline: string[];
  cwd?: string;
}

export interface PaneSnapshot {
  /** Stable pane key shared with the agent-status protocol:
   *  kitty-<kitty pid>-<window id> for kitty, the numeric pane id for wezterm. */
  paneKey: string;
  terminal: 'kitty' | 'wezterm';
  /** /dev/pts/N of the pane's shell, when resolvable. */
  tty?: string;
  title?: string;
  /** Terminal user vars (OSC 1337 SetUserVar). Empty for wezterm — its CLI
   *  does not expose them; wezterm agent detection rides state files/tty. */
  userVars: Record<string, string>;
  foregroundProcesses: ForegroundProcess[];
}

/** Read-only lookups a section may consult. Built once per tick. */
export interface SectionContext {
  nowMs: number;
  /** agent name -> pane key -> fresh active agent state (wezterm-agent-status). */
  agentState(paneKey: string): AgentState | undefined;
  /** tty -> claude transcript path (from /tmp/claude-wezterm correlation). */
  transcriptForTty(tty: string | undefined): string | undefined;
  /** pane key -> fresh renderable summary (wezterm-pane-summary). */
  summary(paneKey: string): string | undefined;
  /** Section names that already produced output for this pane, in tier order. */
  fired: Set<string>;
}

export interface AgentState {
  agent: 'claude' | 'codex' | 'pi';
  model?: string;
  state?: string;
  updatedAtMs: number;
}

export interface Section {
  name: string;
  /** Lower tiers render first (left-most). */
  tier: number;
  /** Return the section's text (no separators) or null to stay silent. */
  detect(snapshot: PaneSnapshot, ctx: SectionContext): string | null;
}

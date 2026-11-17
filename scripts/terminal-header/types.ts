export interface ForegroundProcess {
  pid: number;
  cmdline: string[];
  cwd?: string;
}

export interface PaneSnapshot {
  paneKey: string;
  terminal: string;
  tty?: string;
  title?: string;
  userVars: Record<string, string>;
  foregroundProcesses: ForegroundProcess[];
}

export interface SectionContext {
  nowMs: number;
  agentState(paneKey: string): AgentState | undefined;
  transcriptForTty(tty: string | undefined): string | undefined;
  summary(paneKey: string): string | undefined;
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
  tier: number;
  detect(snapshot: PaneSnapshot, ctx: SectionContext): string | null;
}

export interface TerminalTarget {
  name: string;
  available(): boolean;
  listPanes(): PaneSnapshot[];
}

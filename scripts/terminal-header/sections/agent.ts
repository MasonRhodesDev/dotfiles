import type { PaneSnapshot, Section, SectionContext } from '../types.ts';

const AGENTS: Record<string, { label: string; icon: string }> = {
  claude: { label: 'Claude', icon: '🤖' },
  codex: { label: 'Codex', icon: '✦' },
  pi: { label: 'Pi', icon: 'π' },
};

const AGENT_KIND: Record<string, string> = { '1': 'pi', '2': 'codex', '3': 'claude' };

const SHELL_NAMES = new Set(['fish', 'bash', 'zsh']);

function shortModel(model: string): string {
  if (!model) return '';
  for (const m of ['opus', 'sonnet', 'haiku', 'fable']) {
    if (model.includes(m)) return m;
  }
  return model.replace(/^amazon-bedrock\//, '');
}

// User vars have no TTL: a tmux detach or a kill -9 leaves CLAUDE_ACTIVE=1
// with nothing left to clear it. A single bare interactive shell in the
// foreground means whatever set the vars is gone.
function atBareShell(snapshot: PaneSnapshot): boolean {
  if (snapshot.foregroundProcesses.length !== 1) return false;
  const cmdline = snapshot.foregroundProcesses[0].cmdline;
  if (cmdline.length !== 1) return false;
  const base = (cmdline[0].split('/').pop() ?? '').replace(/^-/, '');
  return SHELL_NAMES.has(base);
}

function render(agent: string, model: string): string {
  const definition = AGENTS[agent];
  let label = definition.label;
  const short = shortModel(model);
  if (short) label = `${label} (${short})`;
  return `${definition.icon} ${label}`;
}

export const agentSection: Section = {
  name: 'agent',
  tier: 10,
  detect(snapshot: PaneSnapshot, ctx: SectionContext): string | null {
    if (atBareShell(snapshot)) return null;

    const uv = snapshot.userVars;
    // 1. Runner-driven user vars (kitty; includes agents at the far end of an
    //    ssh session — the OSC crosses the wire even though env vars don't).
    if (uv.AGENT_ACTIVE === '1') {
      const agent = AGENT_KIND[uv.AGENT_KIND ?? ''];
      if (!agent) return null;
      const state = ctx.agentState(snapshot.paneKey);
      return render(agent, (state?.agent === agent ? state.model : '') ?? '');
    }
    // 2. Claude hook user vars (carry the model directly).
    if (uv.CLAUDE_ACTIVE === '1') {
      return render('claude', uv.CLAUDE_MODEL ?? '');
    }
    if (uv.AGENT_ACTIVE === '0' || uv.CLAUDE_ACTIVE === '0') return null;

    // 3. Fresh active state file (bridge-fed agents without the runner,
    //    and all wezterm panes — its CLI exposes no user vars).
    const state = ctx.agentState(snapshot.paneKey);
    if (state) return render(state.agent, state.model ?? '');

    // 4. Claude correlation by tty (covers wezterm claude panes).
    const transcript = ctx.transcriptForTty(snapshot.tty);
    if (transcript) return render('claude', '');

    return null;
  },
};

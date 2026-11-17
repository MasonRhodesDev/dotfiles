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

const CLAUDE_TITLE = /^[✳⠀-⣿] /u;

export const agentSection: Section = {
  name: 'agent',
  tier: 10,
  detect(snapshot: PaneSnapshot, ctx: SectionContext): string | null {
    if (atBareShell(snapshot)) return null;

    if (ctx.fired.has('ssh') && CLAUDE_TITLE.test(snapshot.title ?? '')) {
      return render('claude', '');
    }

    const uv = snapshot.userVars;
    if (uv.AGENT_ACTIVE === '1') {
      const agent = AGENT_KIND[uv.AGENT_KIND ?? ''];
      if (!agent) return null;
      const state = ctx.agentState(snapshot.paneKey);
      return render(agent, (state?.agent === agent ? state.model : '') ?? '');
    }
    if (uv.CLAUDE_ACTIVE === '1') {
      return render('claude', uv.CLAUDE_MODEL ?? '');
    }
    if (uv.AGENT_ACTIVE === '0' || uv.CLAUDE_ACTIVE === '0') return null;

    const state = ctx.agentState(snapshot.paneKey);
    if (state) return render(state.agent, state.model ?? '');

    const transcript = ctx.transcriptForTty(snapshot.tty);
    if (transcript) return render('claude', '');

    return null;
  },
};

import { spawn } from 'node:child_process';

const BRIDGE = '@home@/scripts/agent-status-bridge.ts';

const events: Record<string, string> = {
  session_start: 'SessionStart',
  before_agent_start: 'BeforeAgentStart',
  agent_start: 'AgentStart',
  tool_execution_start: 'ToolExecutionStart',
  tool_execution_end: 'ToolExecutionEnd',
  turn_end: 'TurnEnd',
  agent_end: 'AgentEnd',
  model_select: 'ModelSelect',
};

function report(payload: Record<string, unknown>, clear = false): void {
  try {
    const child = spawn(process.execPath, [BRIDGE, 'pi', ...(clear ? ['--clear'] : [])], { stdio: ['pipe', 'ignore', 'ignore'] });
    child.on('error', () => {});
    child.stdin.on('error', () => {});
    child.stdin.end(JSON.stringify(payload));
  } catch {
  }
}

function modelOf(model: any): string {
  if (!model) return '';
  if (typeof model === 'string') return model;
  return [model.provider, model.id].filter(Boolean).join('/');
}

export default function (pi: any) {
  for (const [name, hookEventName] of Object.entries(events)) {
    pi.on(name, (event: any, ctx: any) => {
      report({
        hookEventName,
        session_id: ctx?.sessionManager?.getSessionId?.(),
        model: modelOf(event?.model ?? ctx?.model),
        tool_name: event?.toolName,
      });
    });
  }
  pi.on('session_shutdown', (_event: any, ctx: any) => {
    report({ hookEventName: 'SessionEnd', session_id: ctx?.sessionManager?.getSessionId?.() }, true);
  });
}

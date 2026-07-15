#!/usr/bin/env node
import { chmodSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';

interface TestResult {
  name: string;
  passed: boolean;
  error?: string;
}

const results: TestResult[] = [];
const testDir = '/tmp/wezterm-agent-status-tests';
const testRuntimeDir = join(testDir, 'runtime');
rmSync(testRuntimeDir, { recursive: true, force: true });
mkdirSync(testRuntimeDir, { recursive: true });

function run(name: string, fn: () => void): void {
  try {
    fn();
    results.push({ name, passed: true });
    console.log(`✓ ${name}`);
  } catch (error) {
    results.push({ name, passed: false, error: String(error) });
    console.log(`✗ ${name}: ${String(error)}`);
  }
}

function command(name: string, args: string[], options: Parameters<typeof spawnSync>[2] = {}) {
  const result = spawnSync(name, args, { encoding: 'utf8', ...options });
  if (result.status !== 0) {
    throw result.stderr || result.stdout || `${name} ${args.join(' ')} exited ${result.status}`;
  }
  return result;
}

function testEnv(extra: NodeJS.ProcessEnv = {}): NodeJS.ProcessEnv {
  const env: NodeJS.ProcessEnv = { ...process.env, XDG_RUNTIME_DIR: testRuntimeDir, WEZTERM_PANE_SUMMARY_DISABLE_MODEL: '1' };
  // The suite must behave the same run from kitty, wezterm, tmux, or
  // headless: strip the invoking terminal's identity (TERM discrimination in
  // the runner/bridge would otherwise override what a test sets).
  delete env.TERM;
  delete env.KITTY_WINDOW_ID;
  delete env.KITTY_PID;
  delete env.WEZTERM_PANE;
  delete env.TMUX;
  return { ...env, ...extra };
}

function sha256(text: string): string {
  return createHash('sha256').update(text).digest('hex');
}

function stateRoot(env: NodeJS.ProcessEnv = testEnv()): string {
  return env.XDG_RUNTIME_DIR
    ? join(env.XDG_RUNTIME_DIR, 'wezterm-agent-status')
    : join(env.HOME ?? '.', '.cache', 'wezterm-agent-status');
}

run('TypeScript/JS syntax checks pass', () => {
  command('node', ['--check', '/home/mason/scripts/wezterm-agent-bridge.ts']);
  command('node', ['--check', '/home/mason/scripts/wezterm-agent-runner.ts']);
  command('node', ['--check', '/home/mason/scripts/pi-wezterm.ts']);
  command('node', ['--check', '/home/mason/scripts/codex-wezterm.ts']);
  command('node', ['--check', '/home/mason/scripts/wezterm-pane-summarizer.ts']);
  command('node', ['--check', '/home/mason/scripts/terminal-session-task-stack.ts']);
  command('node', ['--check', '/home/mason/.pi/agent/extensions/wezterm-agent-status.ts']);
  command('node', ['--check', '/home/mason/.local/bin/pi']);
});

run('WezTerm config parses', () => {
  command('wezterm', ['--config-file', '/home/mason/.config/wezterm/wezterm.lua', 'show-keys'], { env: testEnv() });
});

run('Lua module detects/renders explicit pane state in WezTerm runtime', () => {
  const root = stateRoot();
  const stateDir = join(root, 'pi');
  mkdirSync(stateDir, { recursive: true });
  writeFileSync(join(stateDir, 'pane-424242.json'), `${JSON.stringify({
    active: true,
    agent: 'pi',
    sessionId: 'test-session',
    pane: '424242',
    model: 'amazon-bedrock/us.anthropic.claude-haiku-4-5-20251001-v1:0',
    state: 'tool',
    activity: 'Running command',
    updatedAt: new Date().toISOString(),
    updatedAtMs: Date.now(),
  })}\n`);

  const summaryDir = join(testRuntimeDir, 'wezterm-pane-summary');
  mkdirSync(summaryDir, { recursive: true });
  writeFileSync(join(summaryDir, 'pane-424242.json'), `${JSON.stringify({
    active: true,
    pane: '424242',
    source: 'terminal-task-stack',
    summary: 'debugging status bar',
    confidence: 'medium',
    sampleHash: 'abc',
    updatedAt: new Date().toISOString(),
    updatedAtMs: Date.now(),
    summarizer: 'ollama',
  })}\n`);

  const configPath = join(testDir, 'wezterm-module-test.lua');
  writeFileSync(configPath, `
local module = assert(loadfile('/home/mason/.config/wezterm/headerModules/claude.lua'))()
local pane = {
  get_user_vars = function()
    return { AGENT_ACTIVE = '1', AGENT_KIND = '1', AGENT_SEQ = '123' }
  end,
  pane_id = function() return 424242 end,
  get_current_working_dir = function() return { file_path = '/home/mason' } end,
}
local active, data = module.detect(pane)
assert(active == true, 'expected active')
assert(data.agent == 'pi', 'expected pi agent')
local component = module.get_component(pane, data)
assert(component:match('π'), component)
assert(component:match('Pi'), component)
assert(component:match('haiku'), component)
assert(not component:match('debugging status bar'), component)
assert(not component:match('Running command'), component)
return {}
`);

  command('wezterm', ['--config-file', configPath, 'show-keys'], { env: testEnv() });
});

run('Lua agent module does not fall back to hook activity as task summary', () => {
  const root = stateRoot();
  const stateDir = join(root, 'pi');
  mkdirSync(stateDir, { recursive: true });
  writeFileSync(join(stateDir, 'pane-424245.json'), `${JSON.stringify({
    active: true,
    agent: 'pi',
    sessionId: 'test-session',
    pane: '424245',
    model: 'amazon-bedrock/us.anthropic.claude-haiku-4-5-20251001-v1:0',
    state: 'tool',
    activity: 'Running command',
    updatedAt: new Date().toISOString(),
    updatedAtMs: Date.now(),
  })}\n`);

  const configPath = join(testDir, 'wezterm-agent-no-hook-summary-test.lua');
  writeFileSync(configPath, `
local module = assert(loadfile('/home/mason/.config/wezterm/headerModules/claude.lua'))()
local pane = {
  get_user_vars = function()
    return { AGENT_ACTIVE = '1', AGENT_KIND = '1', AGENT_SEQ = '123' }
  end,
  pane_id = function() return 424245 end,
  get_current_working_dir = function() return { file_path = '/home/mason' } end,
}
local active, data = module.detect(pane)
assert(active == true, 'expected active')
local component = module.get_component(pane, data)
assert(component:match('π'), component)
assert(component:match('Pi'), component)
assert(component:match('haiku'), component)
assert(not component:match('Running command'), component)
return {}
`);

  command('wezterm', ['--config-file', configPath, 'show-keys'], { env: testEnv() });
});

run('Lua agent module preserves agent identity from AGENT_KIND when state file is stale', () => {
  const configPath = join(testDir, 'wezterm-agent-kind-fallback-test.lua');
  writeFileSync(configPath, `
local module = assert(loadfile('/home/mason/.config/wezterm/headerModules/claude.lua'))()
local pane = {
  get_user_vars = function()
    return { AGENT_ACTIVE = '1', AGENT_KIND = '1', AGENT_SEQ = '123' }
  end,
  pane_id = function() return 424252 end,
}
local active, data = module.detect(pane)
assert(active == true, 'expected active')
local component = module.get_component(pane, data)
assert(component:match('π'), component)
assert(component:match('Pi'), component)
return {}
`);

  command('wezterm', ['--config-file', configPath, 'show-keys'], { env: testEnv() });
});

run('Lua module renders Codex state via AGENT_KIND', () => {
  const root = stateRoot();
  const stateDir = join(root, 'codex');
  mkdirSync(stateDir, { recursive: true });
  writeFileSync(join(stateDir, 'pane-424243.json'), `${JSON.stringify({
    active: true,
    agent: 'codex',
    sessionId: 'codex-session',
    pane: '424243',
    model: 'gpt-5.5',
    state: 'tool',
    activity: 'Running command',
    updatedAt: new Date().toISOString(),
    updatedAtMs: Date.now(),
  })}\n`);

  const configPath = join(testDir, 'wezterm-codex-module-test.lua');
  writeFileSync(configPath, `
local module = assert(loadfile('/home/mason/.config/wezterm/headerModules/claude.lua'))()
local pane = {
  get_user_vars = function()
    return { AGENT_ACTIVE = '1', AGENT_KIND = '2', AGENT_SEQ = '123' }
  end,
  pane_id = function() return 424243 end,
  get_current_working_dir = function() return { file_path = '/home/mason' } end,
}
local active, data = module.detect(pane)
assert(active == true, 'expected active')
assert(data.agent == 'codex', 'expected codex agent')
local component = module.get_component(pane, data)
assert(component:match('✦'), component)
assert(component:match('Codex'), component)
assert(not component:match('Running command'), component)
return {}
`);

  command('wezterm', ['--config-file', configPath, 'show-keys'], { env: testEnv() });
});

run('Header summary is a separate right-most component', () => {
  const agentRoot = stateRoot();
  const stateDir = join(agentRoot, 'pi');
  mkdirSync(stateDir, { recursive: true });
  writeFileSync(join(stateDir, 'pane-424250.json'), `${JSON.stringify({
    active: true,
    agent: 'pi',
    sessionId: 'test-session',
    pane: '424250',
    paneTty: '/dev/pts/test424250',
    model: 'openai/gpt-5.5',
    state: 'idle',
    activity: '',
    updatedAt: new Date().toISOString(),
    updatedAtMs: Date.now(),
  })}\n`);

  const summaryRoot = join(testRuntimeDir, 'wezterm-pane-summary');
  mkdirSync(summaryRoot, { recursive: true });
  writeFileSync(join(summaryRoot, 'pane-424250.json'), `${JSON.stringify({
    active: true,
    pane: '424250',
    source: 'terminal-task-stack',
    summary: 'reviewing status bar behavior',
    confidence: 'medium',
    sampleHash: 'abc',
    updatedAt: new Date().toISOString(),
    updatedAtMs: Date.now(),
    summarizer: 'ollama',
  })}\n`);

  const configPath = join(testDir, 'wezterm-summary-rightmost-test.lua');
  writeFileSync(configPath, `
local loader = assert(loadfile('/home/mason/.config/wezterm/headerModulesLoader.lua'))()
local claude = assert(loadfile('/home/mason/.config/wezterm/headerModules/claude.lua'))()
local pane_summary = assert(loadfile('/home/mason/.config/wezterm/headerModules/pane_summary.lua'))()
local modules = {
  claude = claude,
  beads = {
    priority = 999,
    detect = function() return true, nil end,
    get_component = function() return '📋 tasks' end,
  },
  pane_summary = pane_summary,
}
local pane = {
  get_user_vars = function() return { AGENT_ACTIVE = '1', AGENT_KIND = '1' } end,
  pane_id = function() return 424250 end,
  get_tty_name = function() return '/dev/pts/test424250' end,
}
local left, right = loader.collect_status_components(modules, nil, pane)
local joined = table.concat(left, ' | ')
assert(joined:match('π Pi'), joined)
assert(joined:match('📋 tasks'), joined)
assert(not joined:match('reviewing status bar behavior'), joined)
assert(right == 'reviewing status bar behavior', tostring(right))
return {}
`);

  command('wezterm', ['--config-file', configPath, 'show-keys'], { env: testEnv() });
});

run('Lua agent module rejects unsafe cached pane summary text', () => {
  const agentRoot = stateRoot();
  const stateDir = join(agentRoot, 'pi');
  mkdirSync(stateDir, { recursive: true });
  writeFileSync(join(stateDir, 'pane-424248.json'), `${JSON.stringify({
    active: true,
    agent: 'pi',
    sessionId: 'test-session',
    pane: '424248',
    model: 'openai/gpt-5.5',
    state: 'idle',
    activity: '',
    updatedAt: new Date().toISOString(),
    updatedAtMs: Date.now(),
  })}\n`);

  const summaryRoot = join(testRuntimeDir, 'wezterm-pane-summary');
  mkdirSync(summaryRoot, { recursive: true });
  writeFileSync(join(summaryRoot, 'pane-424248.json'), `${JSON.stringify({
    active: true,
    pane: '424248',
    source: 'terminal-task-stack',
    summary: 'mcp_health finished',
    confidence: 'medium',
    sampleHash: 'abc',
    updatedAt: new Date().toISOString(),
    updatedAtMs: Date.now(),
    summarizer: 'ollama',
  })}\n`);

  const configPath = join(testDir, 'wezterm-agent-unsafe-summary-test.lua');
  writeFileSync(configPath, `
local module = assert(loadfile('/home/mason/.config/wezterm/headerModules/claude.lua'))()
local pane = {
  get_user_vars = function() return { AGENT_ACTIVE = '1', AGENT_KIND = '1' } end,
  pane_id = function() return 424248 end,
}
local active, data = module.detect(pane)
assert(active == true, 'expected active')
local component = module.get_component(pane, data)
assert(component:match('Pi'), component)
assert(not component:match('mcp_health'), component)
assert(not component:match('finished'), component)
return {}
`);

  command('wezterm', ['--config-file', configPath, 'show-keys'], { env: testEnv() });
});

run('Pane summary module rejects unsafe cached summary text', () => {
  const root = join(testRuntimeDir, 'wezterm-pane-summary');
  mkdirSync(root, { recursive: true });
  writeFileSync(join(root, 'pane-424249.json'), `${JSON.stringify({
    active: true,
    pane: '424249',
    paneTty: '/dev/pts/test424249',
    source: 'terminal-task-stack',
    summary: 'mcp health check completed',
    confidence: 'medium',
    sampleHash: 'abc',
    updatedAt: new Date().toISOString(),
    updatedAtMs: Date.now(),
    summarizer: 'ollama',
  })}\n`);

  const configPath = join(testDir, 'wezterm-pane-unsafe-summary-test.lua');
  writeFileSync(configPath, `
local module = assert(loadfile('/home/mason/.config/wezterm/headerModules/pane_summary.lua'))()
local pane = {
  get_user_vars = function() return {} end,
  pane_id = function() return 424249 end,
  get_tty_name = function() return '/dev/pts/test424249' end,
}
local active = module.detect(pane)
assert(active == false, 'expected unsafe summary to be rejected')
return {}
`);

  command('wezterm', ['--config-file', configPath, 'show-keys'], { env: testEnv() });
});

run('Pane summary module rejects comma-list summaries', () => {
  const root = join(testRuntimeDir, 'wezterm-pane-summary');
  mkdirSync(root, { recursive: true });
  writeFileSync(join(root, 'pane-424255.json'), `${JSON.stringify({
    active: true,
    pane: '424255',
    paneTty: '/dev/pts/test424255',
    source: 'terminal-task-stack',
    summary: 'checking system status, reviewing tokens',
    confidence: 'medium',
    sampleHash: 'abc',
    updatedAt: new Date().toISOString(),
    updatedAtMs: Date.now(),
    summarizer: 'ollama',
  })}\n`);

  const configPath = join(testDir, 'wezterm-pane-list-summary-test.lua');
  writeFileSync(configPath, `
local module = assert(loadfile('/home/mason/.config/wezterm/headerModules/pane_summary.lua'))()
local pane = {
  get_user_vars = function() return {} end,
  pane_id = function() return 424255 end,
  get_tty_name = function() return '/dev/pts/test424255' end,
}
local active = module.detect(pane)
assert(active == false, 'expected comma-list summary to be rejected')
return {}
`);

  command('wezterm', ['--config-file', configPath, 'show-keys'], { env: testEnv() });
});
run('Pane summary module rejects path-like summaries', () => {
  const root = join(testRuntimeDir, 'wezterm-pane-summary');
  mkdirSync(root, { recursive: true });
  writeFileSync(join(root, 'pane-424254.json'), `${JSON.stringify({
    active: true,
    pane: '424254',
    paneTty: '/dev/pts/test424254',
    source: 'terminal-task-stack',
    summary: 'reviewing src/auth.ts',
    confidence: 'medium',
    sampleHash: 'abc',
    updatedAt: new Date().toISOString(),
    updatedAtMs: Date.now(),
    summarizer: 'ollama',
  })}\n`);

  const configPath = join(testDir, 'wezterm-pane-path-summary-test.lua');
  writeFileSync(configPath, `
local module = assert(loadfile('/home/mason/.config/wezterm/headerModules/pane_summary.lua'))()
local pane = {
  get_user_vars = function() return {} end,
  pane_id = function() return 424254 end,
  get_tty_name = function() return '/dev/pts/test424254' end,
}
local active = module.detect(pane)
assert(active == false, 'expected path-like summary to be rejected')
return {}
`);

  command('wezterm', ['--config-file', configPath, 'show-keys'], { env: testEnv() });
});

run('Pane summary module rejects plural hook lifecycle summaries', () => {
  const root = join(testRuntimeDir, 'wezterm-pane-summary');
  mkdirSync(root, { recursive: true });
  writeFileSync(join(root, 'pane-424253.json'), `${JSON.stringify({
    active: true,
    pane: '424253',
    paneTty: '/dev/pts/test424253',
    source: 'terminal-task-stack',
    summary: 'reading files',
    confidence: 'medium',
    sampleHash: 'abc',
    updatedAt: new Date().toISOString(),
    updatedAtMs: Date.now(),
    summarizer: 'ollama',
  })}\n`);

  const configPath = join(testDir, 'wezterm-pane-plural-lifecycle-summary-test.lua');
  writeFileSync(configPath, `
local module = assert(loadfile('/home/mason/.config/wezterm/headerModules/pane_summary.lua'))()
local pane = {
  get_user_vars = function() return {} end,
  pane_id = function() return 424253 end,
  get_tty_name = function() return '/dev/pts/test424253' end,
}
local active = module.detect(pane)
assert(active == false, 'expected plural lifecycle summary to be rejected')
return {}
`);

  command('wezterm', ['--config-file', configPath, 'show-keys'], { env: testEnv() });
});

run('Pane summary module rejects vague working summaries', () => {
  const root = join(testRuntimeDir, 'wezterm-pane-summary');
  mkdirSync(root, { recursive: true });
  writeFileSync(join(root, 'pane-424251.json'), `${JSON.stringify({
    active: true,
    pane: '424251',
    paneTty: '/dev/pts/test424251',
    source: 'terminal-task-stack',
    summary: 'working on a fresh wezterm and pi instance',
    confidence: 'medium',
    sampleHash: 'abc',
    updatedAt: new Date().toISOString(),
    updatedAtMs: Date.now(),
    summarizer: 'ollama',
  })}\n`);

  const configPath = join(testDir, 'wezterm-pane-working-summary-test.lua');
  writeFileSync(configPath, `
local module = assert(loadfile('/home/mason/.config/wezterm/headerModules/pane_summary.lua'))()
local pane = {
  get_user_vars = function() return {} end,
  pane_id = function() return 424251 end,
  get_tty_name = function() return '/dev/pts/test424251' end,
}
local active = module.detect(pane)
assert(active == false, 'expected working summary to be rejected')
return {}
`);

  command('wezterm', ['--config-file', configPath, 'show-keys'], { env: testEnv() });
});

run('Legacy Claude does not fall back to CLAUDE_ACTIVITY when no pane summary exists', () => {
  const configPath = join(testDir, 'wezterm-claude-no-hook-summary-test.lua');
  writeFileSync(configPath, `
local module = assert(loadfile('/home/mason/.config/wezterm/headerModules/claude.lua'))()
local pane = {
  get_user_vars = function()
    return { CLAUDE_ACTIVE = '1', CLAUDE_MODEL = 'sonnet', CLAUDE_ACTIVITY = 'old hook task' }
  end,
  pane_id = function() return 424246 end,
  get_current_working_dir = function() return { file_path = '/home/mason' } end,
}
local active, data = module.detect(pane)
assert(active == true, 'expected active')
local component = module.get_component(pane, data)
assert(component:match('Claude'), component)
assert(not component:match('old hook task'), component)
return {}
`);

  command('wezterm', ['--config-file', configPath, 'show-keys'], { env: testEnv() });
});

run('Pane summary can render despite stale AGENT_ACTIVE when no fresh agent state exists', () => {
  const root = join(testRuntimeDir, 'wezterm-pane-summary');
  mkdirSync(root, { recursive: true });
  writeFileSync(join(root, 'pane-424247.json'), `${JSON.stringify({
    active: true,
    pane: '424247',
    paneTty: '/dev/pts/test424247',
    source: 'terminal-task-stack',
    summary: 'reviewing errors',
    confidence: 'medium',
    sampleHash: 'abc',
    updatedAt: new Date().toISOString(),
    updatedAtMs: Date.now(),
    summarizer: 'ollama',
  })}\n`);

  const configPath = join(testDir, 'wezterm-stale-agent-var-summary-test.lua');
  writeFileSync(configPath, `
local module = assert(loadfile('/home/mason/.config/wezterm/headerModules/pane_summary.lua'))()
local pane = {
  get_user_vars = function() return { AGENT_ACTIVE = '1', AGENT_KIND = '1' } end,
  pane_id = function() return 424247 end,
  get_tty_name = function() return '/dev/pts/test424247' end,
}
local active, data = module.detect(pane)
assert(active == true, 'expected summary active')
local component = module.get_component(pane, data)
assert(component:match('reviewing errors'), component)
return {}
`);

  command('wezterm', ['--config-file', configPath, 'show-keys'], { env: testEnv() });
});

run('Pane summary module renders explicit summary state', () => {
  const root = join(testRuntimeDir, 'wezterm-pane-summary');
  mkdirSync(root, { recursive: true });
  writeFileSync(join(root, 'pane-424244.json'), `${JSON.stringify({
    active: true,
    pane: '424244',
    paneTty: '/dev/pts/test424244',
    source: 'terminal-task-stack',
    summary: 'debugging status bar',
    confidence: 'medium',
    sampleHash: 'abc',
    updatedAt: new Date().toISOString(),
    updatedAtMs: Date.now(),
    summarizer: 'ollama',
  })}\n`);

  const configPath = join(testDir, 'wezterm-pane-summary-test.lua');
  writeFileSync(configPath, `
local module = assert(loadfile('/home/mason/.config/wezterm/headerModules/pane_summary.lua'))()
local pane = {
  get_user_vars = function() return {} end,
  pane_id = function() return 424244 end,
  get_tty_name = function() return '/dev/pts/test424244' end,
}
local active, data = module.detect(pane)
assert(active == true, 'expected active')
local component = module.get_component(pane, data)
assert(component == 'debugging status bar', component)
return {}
`);

  command('wezterm', ['--config-file', configPath, 'show-keys'], { env: testEnv() });
});

run('Pane summarizer writes at least one pane summary', () => {
  command('node', ['/home/mason/scripts/wezterm-pane-summarizer.ts', 'force-once'], { env: testEnv() });
  const root = join(testRuntimeDir, 'wezterm-pane-summary');
  const result = command('sh', ['-lc', `find ${JSON.stringify(root)} -maxdepth 1 -name 'pane-*.json' | head -1`]);
  if (!result.stdout.trim()) throw new Error('no pane summary state file was written');
});

run('Pane summarizer keeps existing summary visible while changed buffer is not quiet', () => {
  const env = testEnv({ WEZTERM_PANE_SUMMARY_DISABLE_MODEL: '0' });
  const binDir = join(testDir, 'fake-bin-changed');
  mkdirSync(binDir, { recursive: true });
  const fakeWezterm = join(binDir, 'wezterm');
  writeFileSync(fakeWezterm, `#!/bin/sh
if [ "$1" = "cli" ] && [ "$2" = "list" ]; then
  printf '%s\n' '[{"pane_id":901,"title":"π - mason","window_title":"π - mason","is_active":true,"tty_name":"/dev/pts/test901"}]'
  exit 0
fi
if [ "$1" = "cli" ] && [ "$2" = "get-text" ]; then
  printf '%s\n' 'new pane output that has not settled yet'
  exit 0
fi
exit 1
`);
  chmodSync(fakeWezterm, 0o755);

  const root = join(testRuntimeDir, 'wezterm-pane-summary');
  mkdirSync(root, { recursive: true });
  const statePath = join(root, 'pane-901.json');
  const before = Date.now();
  writeFileSync(statePath, `${JSON.stringify({
    active: true,
    pane: '901',
    paneTty: '/dev/pts/test901',
    source: 'terminal-task-stack',
    summary: 'reviewing status bar behavior',
    confidence: 'medium',
    sampleHash: sha256('old pane output'),
    updatedAt: new Date(before).toISOString(),
    updatedAtMs: before,
    summarizer: 'ollama',
  })}\n`);

  spawnSync('node', ['/home/mason/scripts/wezterm-pane-summarizer.ts', 'daemon'], {
    env: { ...env, PATH: `${binDir}:${process.env.PATH ?? ''}` },
    encoding: 'utf8',
    timeout: 2500,
  });

  const state = JSON.parse(readFileSync(statePath, 'utf8'));
  if (state.active !== true) throw new Error('existing summary was cleared on buffer change');
  if (state.summary !== 'reviewing status bar behavior') throw new Error(`summary changed before quiet: ${state.summary}`);
  if (state.updatedAtMs !== before) throw new Error('existing summary timestamp should not be refreshed before a model replacement');
});

run('Pane summarizer salvages first valid clause from model list output', () => {
  const env = testEnv({ WEZTERM_PANE_SUMMARY_DISABLE_MODEL: '0' });
  const binDir = join(testDir, 'fake-bin-long-model');
  mkdirSync(binDir, { recursive: true });
  const fakeWezterm = join(binDir, 'wezterm');
  writeFileSync(fakeWezterm, `#!/bin/sh
if [ "$1" = "cli" ] && [ "$2" = "list" ]; then
  printf '%s\n' '[{"pane_id":903,"title":"π - mason","window_title":"π - mason","is_active":true,"tty_name":"/dev/pts/test903"}]'
  exit 0
fi
if [ "$1" = "cli" ] && [ "$2" = "get-text" ]; then
  printf '%s\n' 'mcp health status shows expired oauth tokens'
  exit 0
fi
exit 1
`);
  chmodSync(fakeWezterm, 0o755);

  const fakeNode = join(binDir, 'node');
  const wrapper = join(binDir, 'fake-node-wrapper.ts');
  writeFileSync(wrapper, `
process.argv[2] = 'force-once';
const realFetch = globalThis.fetch;
globalThis.fetch = async () => new Response(JSON.stringify({ message: { content: process.env.FAKE_MODEL_SUMMARY || 'Checking system status, reviewing OAuth tokens, cleaning up duplicate configs, and ensuring routing' } }), { status: 200, headers: { 'content-type': 'application/json' } });
await import('/home/mason/scripts/wezterm-pane-summarizer.ts');
globalThis.fetch = realFetch;
`);
  writeFileSync(fakeNode, `#!/bin/sh
exec ${JSON.stringify(process.execPath)} ${JSON.stringify(wrapper)} "$@"
`);
  chmodSync(fakeNode, 0o755);

  command(fakeNode, ['/home/mason/scripts/wezterm-pane-summarizer.ts', 'force-once'], {
    env: { ...env, PATH: `${binDir}:${process.env.PATH ?? ''}` },
  });

  let state = JSON.parse(readFileSync(join(testRuntimeDir, 'wezterm-pane-summary', 'pane-903.json'), 'utf8'));
  if (state.summary !== 'checking system status') throw new Error(`unexpected summary ${state.summary}`);
  if (state.confidence !== 'medium') throw new Error(`unexpected confidence ${state.confidence}`);
  if (state.summarizer !== 'ollama') throw new Error(`unexpected summarizer ${state.summarizer}`);

  command(fakeNode, ['/home/mason/scripts/wezterm-pane-summarizer.ts', 'force-once'], {
    env: { ...env, PATH: `${binDir}:${process.env.PATH ?? ''}`, FAKE_MODEL_SUMMARY: 'Checking status, ensuring routing' },
  });
  state = JSON.parse(readFileSync(join(testRuntimeDir, 'wezterm-pane-summary', 'pane-903.json'), 'utf8'));
  if (state.summary !== 'checking status') throw new Error(`unexpected short-list summary ${state.summary}`);
});

run('Pane summarizer writes only low-confidence fallback diagnostics when model is disabled', () => {
  const env = testEnv({ WEZTERM_PANE_SUMMARY_DISABLE_MODEL: '1' });
  const binDir = join(testDir, 'fake-bin-fresh-edit-fallback');
  mkdirSync(binDir, { recursive: true });
  const fakeWezterm = join(binDir, 'wezterm');
  writeFileSync(fakeWezterm, `#!/bin/sh
if [ "$1" = "cli" ] && [ "$2" = "list" ]; then
  printf '%s\n' '[{"pane_id":904,"title":"π - mason","window_title":"π - mason","is_active":true,"tty_name":"/dev/pts/test904"}]'
  exit 0
fi
if [ "$1" = "cli" ] && [ "$2" = "get-text" ]; then
  printf '%s\n' 'successfully wrote files'
  exit 0
fi
exit 1
`);
  chmodSync(fakeWezterm, 0o755);

  command('node', ['/home/mason/scripts/wezterm-pane-summarizer.ts', 'force-once'], {
    env: { ...env, PATH: `${binDir}:${process.env.PATH ?? ''}` },
  });

  const state = JSON.parse(readFileSync(join(testRuntimeDir, 'wezterm-pane-summary', 'pane-904.json'), 'utf8'));
  if (state.summary !== 'updating project') throw new Error(`unexpected fallback summary ${state.summary}`);
  if (state.confidence !== 'low') throw new Error(`fallback should not render: ${state.confidence}`);
  if (state.summarizer !== 'fallback') throw new Error(`unexpected summarizer ${state.summarizer}`);
  if (state.active !== false) throw new Error('fallback diagnostic render state should be inactive');
});

run('Terminal task stack pushes a new task when latest user input changes', () => {
  const code = [
    "const mod = await import('/home/mason/scripts/terminal-session-task-stack.ts');",
    "let response = 'Reviewing architecture';",
    "globalThis.fetch = async () => new Response(JSON.stringify({ message: { content: response } }), { status: 200, headers: { 'content-type': 'application/json' } });",
    "const options = { model: 'test-model', ollamaUrl: 'http://127.0.0.1:11434' };",
    "let result = await mod.updateTerminalTaskStack({ paneId: '905', ttyName: '/dev/pts/test905', text: 'User: review architecture\\nall checks pass', observedAtMs: 1000 }, undefined, options);",
    "response = 'Designing task stack';",
    "result = await mod.updateTerminalTaskStack({ paneId: '905', ttyName: '/dev/pts/test905', text: 'User: design task stack\\nall checks pass', observedAtMs: 2000 }, result.state, options);",
    "if (result.state.source !== 'terminal-task-stack') throw new Error('bad source');",
    "if (result.state.tasks.length !== 2) throw new Error('expected two tasks, got ' + result.state.tasks.length);",
    "if (result.state.tasks[0].status !== 'superseded') throw new Error('first task not superseded');",
    "if (result.state.tasks[1].status !== 'active') throw new Error('latest task not active');",
    "if (result.state.tasks[1].summary !== 'designing task stack') throw new Error('bad latest summary ' + result.state.tasks[1].summary);",
    "if (!result.visibleSummary || result.visibleSummary.summary !== 'designing task stack') throw new Error('visible summary did not use latest task');",
  ].join('\n');
  command(process.execPath, ['--input-type=module', '-e', code], { env: testEnv() });
});
run('Terminal task stack does not consume a new input hash when model fails', () => {
  const code = [
    "const mod = await import('/home/mason/scripts/terminal-session-task-stack.ts');",
    "let response = 'Initial task';",
    "let fail = false;",
    "globalThis.fetch = async () => fail ? new Response('{}', { status: 500 }) : new Response(JSON.stringify({ message: { content: response } }), { status: 200, headers: { 'content-type': 'application/json' } });",
    "const options = { model: 'test-model', ollamaUrl: 'http://127.0.0.1:11434' };",
    "let result = await mod.updateTerminalTaskStack({ paneId: '906', ttyName: '/dev/pts/test906', text: 'User: initial task', observedAtMs: 1000 }, undefined, options);",
    "fail = true;",
    "result = await mod.updateTerminalTaskStack({ paneId: '906', ttyName: '/dev/pts/test906', text: 'User: next task', observedAtMs: 2000 }, result.state, options);",
    "fail = false; response = 'Next task';",
    "result = await mod.updateTerminalTaskStack({ paneId: '906', ttyName: '/dev/pts/test906', text: 'User: next task', observedAtMs: 3000 }, result.state, options);",
    "if (result.state.tasks.length !== 2) throw new Error('expected pushed task after model recovered, got ' + result.state.tasks.length);",
    "if (result.state.tasks[1].summary !== 'next task') throw new Error('bad recovered task ' + result.state.tasks[1].summary);",
  ].join('\n');
  command(process.execPath, ['--input-type=module', '-e', code], { env: testEnv() });
});

run('Terminal task stack detects framed and Original task prompts', () => {
  const code = [
    "const mod = await import('/home/mason/scripts/terminal-session-task-stack.ts');",
    "let response = 'First framed task';",
    "globalThis.fetch = async () => new Response(JSON.stringify({ message: { content: response } }), { status: 200, headers: { 'content-type': 'application/json' } });",
    "const options = { model: 'test-model', ollamaUrl: 'http://127.0.0.1:11434' };",
    "let result = await mod.updateTerminalTaskStack({ paneId: '907', ttyName: '/dev/pts/test907', text: '│ > fix framed prompt', observedAtMs: 1000 }, undefined, options);",
    "response = 'Second original task';",
    "result = await mod.updateTerminalTaskStack({ paneId: '907', ttyName: '/dev/pts/test907', text: 'Original task: implement terminal session task stack', observedAtMs: 2000 }, result.state, options);",
    "if (result.state.tasks.length !== 2) throw new Error('expected two detected prompt tasks, got ' + result.state.tasks.length);",
    "if (result.state.tasks[1].summary !== 'second original task') throw new Error('bad latest prompt task ' + result.state.tasks[1].summary);",
  ].join('\n');
  command(process.execPath, ['--input-type=module', '-e', code], { env: testEnv() });
});
run('Terminal task stack honors structured model task-shift decisions', () => {
  const code = [
    "const mod = await import('/home/mason/scripts/terminal-session-task-stack.ts');",
    "let response = { summary: 'Initial task', taskShift: 'new_task' };",
    "globalThis.fetch = async () => new Response(JSON.stringify({ message: { content: JSON.stringify(response) } }), { status: 200, headers: { 'content-type': 'application/json' } });",
    "const options = { model: 'test-model', ollamaUrl: 'http://127.0.0.1:11434' };",
    "let result = await mod.updateTerminalTaskStack({ paneId: '911', ttyName: '/dev/pts/test911', text: 'User: initial task', observedAtMs: 1000 }, undefined, options);",
    "response = { summary: 'Initial task clarified', taskShift: 'same_task' };",
    "result = await mod.updateTerminalTaskStack({ paneId: '911', ttyName: '/dev/pts/test911', text: 'User: clarify initial task', observedAtMs: 2000 }, result.state, options);",
    "if (result.state.tasks.length !== 1) throw new Error('same_task model decision still pushed a task');",
    "if (result.state.tasks[0].summary !== 'initial task clarified') throw new Error('same task summary not updated');",
    "response = { summary: 'Next task', taskShift: 'new_task' };",
    "result = await mod.updateTerminalTaskStack({ paneId: '911', ttyName: '/dev/pts/test911', text: 'User: next task', observedAtMs: 3000 }, result.state, options);",
    "if (result.state.tasks.length !== 2) throw new Error('new_task model decision did not push');",
  ].join('\n');
  command(process.execPath, ['--input-type=module', '-e', code], { env: testEnv() });
});
run('Terminal task redaction preserves normal session wording and redacts common tokens', () => {
  const code = [
    "const mod = await import('/home/mason/scripts/terminal-session-task-stack.ts');",
    "const redacted = mod.redactTerminalText('User: implement terminal session task stack\\nexport GITHUB_TOKEN=ghp_abcdefghijklmnopqrstuvwxyz123456\\ngithub_pat_abcdefghijklmnopqrstuvwxyz_1234567890\\n//registry.npmjs.org/:_authToken=npm_abcdefghijklmnopqrstuvwxyz');",
    "if (!redacted.includes('terminal session task stack')) throw new Error('ordinary session wording was redacted');",
    "if (redacted.includes('ghp_') || redacted.includes('github_pat_') || redacted.includes('npm_abcdefghijklmnopqrstuvwxyz')) throw new Error('common token was not redacted: ' + redacted);",
  ].join('\n');
  command(process.execPath, ['--input-type=module', '-e', code], { env: testEnv() });
});

run('Terminal task redaction keeps authorization prose as task input', () => {
  const code = [
    "const mod = await import('/home/mason/scripts/terminal-session-task-stack.ts');",
    "globalThis.fetch = async () => new Response(JSON.stringify({ message: { content: 'Fixing authorization middleware' } }), { status: 200, headers: { 'content-type': 'application/json' } });",
    "const result = await mod.updateTerminalTaskStack({ paneId: '909', ttyName: '/dev/pts/test909', text: 'User: fix authorization middleware', observedAtMs: 1000 }, undefined, { model: 'test-model', ollamaUrl: 'http://127.0.0.1:11434' });",
    "if (!result.visibleSummary || result.visibleSummary.summary !== 'fixing authorization middleware') throw new Error('authorization prose was not summarized');",
  ].join('\n');
  command(process.execPath, ['--input-type=module', '-e', code], { env: testEnv() });
});

run('Terminal task stack ignores bare npm output prompts', () => {
  const code = [
    "const mod = await import('/home/mason/scripts/terminal-session-task-stack.ts');",
    "let response = 'Running tests';",
    "globalThis.fetch = async () => new Response(JSON.stringify({ message: { content: response } }), { status: 200, headers: { 'content-type': 'application/json' } });",
    "let result = await mod.updateTerminalTaskStack({ paneId: '910', ttyName: '/dev/pts/test910', text: 'User: run tests', observedAtMs: 1000 }, undefined, { model: 'test-model', ollamaUrl: 'http://127.0.0.1:11434' });",
    "response = 'Still running tests';",
    "result = await mod.updateTerminalTaskStack({ paneId: '910', ttyName: '/dev/pts/test910', text: 'User: run tests\\n> package@1.0.0 test\\n> vitest run', observedAtMs: 2000 }, result.state, { model: 'test-model', ollamaUrl: 'http://127.0.0.1:11434' });",
    "if (result.state.tasks.length !== 1) throw new Error('bare npm output was treated as a new user input');",
  ].join('\n');
  command(process.execPath, ['--input-type=module', '-e', code], { env: testEnv() });
});
run('Terminal task stack detects common shell prompts and ignores hash comments', () => {
  const code = [
    "const mod = await import('/home/mason/scripts/terminal-session-task-stack.ts');",
    "let response = 'Running tests';",
    "globalThis.fetch = async () => new Response(JSON.stringify({ message: { content: JSON.stringify({ summary: response, taskShift: 'new_task' }) } }), { status: 200, headers: { 'content-type': 'application/json' } });",
    "const options = { model: 'test-model', ollamaUrl: 'http://127.0.0.1:11434' };",
    "let result = await mod.updateTerminalTaskStack({ paneId: '912', ttyName: '/dev/pts/test912', text: '~/repo main $ npm test', observedAtMs: 1000 }, undefined, options);",
    "response = 'Still running tests';",
    "globalThis.fetch = async () => new Response(JSON.stringify({ message: { content: JSON.stringify({ summary: response, taskShift: 'same_task' }) } }), { status: 200, headers: { 'content-type': 'application/json' } });",
    "result = await mod.updateTerminalTaskStack({ paneId: '912', ttyName: '/dev/pts/test912', text: '~/repo main $ npm test\\n# markdown heading from output', observedAtMs: 2000 }, result.state, options);",
    "if (result.state.tasks.length !== 1) throw new Error('hash comment/output caused task push');",
  ].join('\n');
  command(process.execPath, ['--input-type=module', '-e', code], { env: testEnv() });
});
run('Terminal task stack rejects prior state without matching TTY', () => {
  const code = [
    "const mod = await import('/home/mason/scripts/terminal-session-task-stack.ts');",
    "globalThis.fetch = async () => new Response(JSON.stringify({ message: { content: 'Fresh task' } }), { status: 200, headers: { 'content-type': 'application/json' } });",
    "const previous = { paneId: '908', source: 'terminal-task-stack', activeTaskId: 'old', tasks: [{ id: 'old', summary: 'old task', intent: 'old intent', evidenceDigest: 'old', status: 'active', inputHashes: ['old'], outputHashes: ['old'], firstSeenMs: 1, lastSeenMs: 1, summaryUpdatedAtMs: 1, confidence: 'medium', summarizer: 'ollama' }], lastObservedHash: 'old', lastRedactedHash: 'old', lastInputHash: 'old', updatedAtMs: 1 };",
    "const result = await mod.updateTerminalTaskStack({ paneId: '908', ttyName: '/dev/pts/new908', text: 'User: fresh task', observedAtMs: 1000 }, previous, { model: 'test-model', ollamaUrl: 'http://127.0.0.1:11434' });",
    "if (result.state.tasks.length !== 1) throw new Error('stale tty-less prior state was reused');",
    "if (result.state.tasks[0].summary !== 'fresh task') throw new Error('fresh state not created');",
  ].join('\n');
  command(process.execPath, ['--input-type=module', '-e', code], { env: testEnv() });
});
run('Pane summarizer preserves existing summary when replacement is rejected', () => {
  const env = testEnv({ WEZTERM_PANE_SUMMARY_DISABLE_MODEL: '1' });
  const binDir = join(testDir, 'fake-bin-rejected-replacement');
  mkdirSync(binDir, { recursive: true });
  const fakeWezterm = join(binDir, 'wezterm');
  writeFileSync(fakeWezterm, `#!/bin/sh
if [ "$1" = "cli" ] && [ "$2" = "list" ]; then
  printf '%s\n' '[{"pane_id":902,"title":"π - mason","window_title":"π - mason","is_active":true,"tty_name":"/dev/pts/test902"}]'
  exit 0
fi
if [ "$1" = "cli" ] && [ "$2" = "get-text" ]; then
  printf '%s\n' 'assorted terminal output without a clear task'
  exit 0
fi
exit 1
`);
  chmodSync(fakeWezterm, 0o755);

  const root = join(testRuntimeDir, 'wezterm-pane-summary');
  mkdirSync(root, { recursive: true });
  const statePath = join(root, 'pane-902.json');
  const before = Date.now();
  writeFileSync(statePath, `${JSON.stringify({
    active: true,
    pane: '902',
    paneTty: '/dev/pts/test902',
    source: 'terminal-task-stack',
    summary: 'reviewing status bar behavior',
    confidence: 'medium',
    sampleHash: sha256('old pane output'),
    updatedAt: new Date(before).toISOString(),
    updatedAtMs: before,
    summarizer: 'ollama',
  })}\n`);

  spawnSync('node', ['/home/mason/scripts/wezterm-pane-summarizer.ts', 'daemon'], {
    env: { ...env, PATH: `${binDir}:${process.env.PATH ?? ''}` },
    encoding: 'utf8',
    timeout: 6500,
  });

  const state = JSON.parse(readFileSync(statePath, 'utf8'));
  if (state.active !== true) throw new Error('existing summary was cleared by rejected replacement');
  if (state.summary !== 'reviewing status bar behavior') throw new Error(`summary changed to rejected replacement: ${state.summary}`);
  if (state.updatedAtMs !== before) throw new Error('existing summary timestamp should not be refreshed after rejected replacement');
});

run('Pane summarizer reuses existing summary state after daemon restart', () => {
  const env = testEnv({ WEZTERM_PANE_SUMMARY_DISABLE_MODEL: '0' });
  const binDir = join(testDir, 'fake-bin');
  mkdirSync(binDir, { recursive: true });
  const fakeWezterm = join(binDir, 'wezterm');
  writeFileSync(fakeWezterm, `#!/bin/sh
if [ "$1" = "cli" ] && [ "$2" = "list" ]; then
  printf '%s\n' '[{"pane_id":900,"title":"π - mason","window_title":"π - mason","is_active":true,"tty_name":"/dev/pts/test900"}]'
  exit 0
fi
if [ "$1" = "cli" ] && [ "$2" = "get-text" ]; then
  printf '%s\n' 'reviewing status bar behavior'
  printf '%s\n' '$ '
  exit 0
fi
exit 1
`);
  chmodSync(fakeWezterm, 0o755);

  const root = join(testRuntimeDir, 'wezterm-pane-summary');
  mkdirSync(root, { recursive: true });
  const statePath = join(root, 'pane-900.json');
  const before = Date.now() - 90_000;
  writeFileSync(statePath, `${JSON.stringify({
    active: true,
    pane: '900',
    paneTty: '/dev/pts/test900',
    source: 'terminal-task-stack',
    summary: 'reviewing status bar behavior',
    confidence: 'medium',
    sampleHash: sha256('reviewing status bar behavior\n$'),
    updatedAt: new Date(before).toISOString(),
    updatedAtMs: before,
    summarizer: 'ollama',
  })}\n`);

  spawnSync('node', ['/home/mason/scripts/wezterm-pane-summarizer.ts', 'daemon'], {
    env: { ...env, PATH: `${binDir}:${process.env.PATH ?? ''}`, OLLAMA_HOST: 'http://203.0.113.1:11434' },
    encoding: 'utf8',
    timeout: 2500,
  });

  const state = JSON.parse(readFileSync(statePath, 'utf8'));
  if (state.active !== true) throw new Error('existing summary was cleared');
  if (state.summary !== 'reviewing status bar behavior') throw new Error(`summary changed: ${state.summary}`);
  if (state.updatedAtMs <= before) throw new Error('existing summary timestamp was not refreshed');
});

run('Bridge writes explicit hook-fed pane state to user-private runtime dir', () => {
  const env = testEnv({ WEZTERM_PANE: '424242' });
  command('node', ['/home/mason/scripts/wezterm-agent-bridge.ts', 'pi'], {
    input: JSON.stringify({
      hook_event_name: 'ToolExecutionStart',
      session_id: 'test-session',
      model: 'test/model',
      tool_name: 'Bash',
    }),
    env,
  });

  const state = JSON.parse(readFileSync(join(stateRoot(env), 'pi', 'pane-424242.json'), 'utf8'));
  if (state.active !== true) throw new Error('state.active not true');
  if (state.agent !== 'pi') throw new Error(`state.agent ${state.agent}`);
  if (state.state !== 'tool') throw new Error(`state.state ${state.state}`);
  if (state.activity !== '') throw new Error(`state.activity ${state.activity}`);
});

run('pi launcher does not emit OSC when stdout is captured', () => {
  const result = command('/home/mason/.local/bin/pi', ['--version'], {
    env: testEnv({ WEZTERM_PANE: '424242' }),
  });
  if (result.stdout.includes('SetUserVar=')) {
    throw new Error('captured stdout was polluted with OSC SetUserVar bytes');
  }
  if (!/\d+\.\d+\.\d+/.test(result.stdout)) {
    throw new Error(`launcher did not run real pi CLI: ${result.stdout}`);
  }
});

run('pi launcher tty OSC branch is syntax-covered', () => {
  const result = spawnSync('sh', ['-lc', 'command -v script'], { encoding: 'utf8' });
  if (result.status !== 0) {
    console.log('  skipped pseudo-tty execution: script(1) is not installed');
    return;
  }

  const ptyResult = command('script', [
    '-qfec',
    'WEZTERM_PANE=424242 /home/mason/.local/bin/pi --version',
    '/dev/null',
  ]);
  if (!ptyResult.stdout.includes('SetUserVar=AGENT_ACTIVE')) {
    throw new Error('pty invocation did not emit AGENT_ACTIVE OSC clear sequence');
  }
  if (!ptyResult.stdout.includes('0.79.10')) {
    throw new Error(`pty invocation did not run real pi CLI: ${ptyResult.stdout}`);
  }
});

run('Shell configs parse', () => {
  command('fish', ['-n', '/home/mason/.config/fish/conf.d/wezterm.fish']);
  command('zsh', ['-n', '/home/mason/.config/zsh/wezterm.zsh']);
});

const failed = results.filter((result) => !result.passed);
console.log(`\n${results.length - failed.length}/${results.length} tests passed`);
if (failed.length > 0) {
  for (const result of failed) {
    console.error(`\n${result.name}\n${result.error}`);
  }
  process.exit(1);
}

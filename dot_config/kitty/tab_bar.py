# Custom tab bar — port of the wezterm headerModules system.
# Renders a left status line per OS window instead of tab titles:
#   [🔐 host] [🤖 Claude (opus) | 📁 ~/repos/foo | summary…]
# Modules: ssh (priority 0), agent, cwd (agent windows only), pane summary.
#
# The bar hides entirely when it has no content: a 2s timer (and the
# on_set_user_var watcher) flips tab_bar_min_tabs between 1 and 9999 and
# relayouts. Visibility is per kitty instance — one instance per OS window
# under Hyprland, so per-window in practice.
#
# State protocol shared with wezterm (written by ~/scripts/wezterm-agent-*):
#   $XDG_RUNTIME_DIR/wezterm-agent-status/<agent>/pane-<key>.json
# where <key> is "kitty-<kitty pid>-<window id>". The kitty pid is in the key
# because Hyprland runs one kitty instance per OS window, so every window's
# id is 1 and window id alone collides across instances. Agent state renders
# from the user-var event path when the agent runs through the runner, and
# falls back to a fresh state file alone (agents whose hooks write via
# wezterm-agent-bridge without the runner, e.g. bare-launched codex).
#
# Pane summaries (written by ~/scripts/wezterm-pane-summarizer.ts):
#   $XDG_RUNTIME_DIR/wezterm-pane-summary/pane-<key>.json

import json
import os
import time

from kitty.boss import get_boss
from kitty.constants import is_wayland
from kitty.fast_data_types import Screen, add_timer, get_options, set_options
from kitty.tab_bar import DrawData, ExtraData, TabBarData, as_rgb
from kitty.utils import color_as_int

STATE_TTL_MS = 2 * 60 * 1000
SUMMARY_TTL_MS = 2 * 60 * 1000
SUMMARY_MAX_CHARS = 60
CWD_MAX_CHARS = 40

AGENTS = {
    'claude': {'label': 'Claude', 'icon': '🤖'},
    'codex': {'label': 'Codex', 'icon': '✦'},
    'pi': {'label': 'Pi', 'icon': 'π'},
}

AGENT_KIND = {'1': 'pi', '2': 'codex', '3': 'claude'}


def _runtime_root(name: str) -> str:
    base = os.environ.get('XDG_RUNTIME_DIR') or os.path.join(os.environ.get('HOME', '.'), '.cache')
    return os.path.join(base, name)


def _pane_key(window_id: int) -> str:
    return f'kitty-{os.getpid()}-{window_id}'


def _short_model(model: str) -> str:
    if not model:
        return ''
    for m in ('opus', 'sonnet', 'haiku', 'fable'):
        if m in model:
            return m
    return model.removeprefix('amazon-bedrock/')


def _read_agent_state(agent: str, window_id: int):
    path = os.path.join(_runtime_root('wezterm-agent-status'), agent, f'pane-{_pane_key(window_id)}.json')
    try:
        with open(path) as f:
            state = json.load(f)
    except (OSError, ValueError):
        return None
    if not isinstance(state, dict) or not state.get('active'):
        return None
    if state.get('agent') not in AGENTS:
        return None
    updated = state.get('updatedAtMs')
    if not isinstance(updated, (int, float)) or (time.time() * 1000) - updated > STATE_TTL_MS:
        return None
    return state


def _scan_agent_state(window_id: int):
    best = None
    for agent in AGENTS:
        state = _read_agent_state(agent, window_id)
        if state and (best is None or (state.get('updatedAtMs') or 0) > (best.get('updatedAtMs') or 0)):
            best = state
    return best


def _at_bare_shell(window) -> bool:
    # User vars have no TTL: a tmux detach or a kill -9 leaves CLAUDE_ACTIVE=1
    # on the window with nothing left to clear it. A single bare interactive
    # shell in the foreground means whatever set the vars is gone.
    try:
        procs = window.child.foreground_processes
    except Exception:
        return False
    if len(procs) != 1:
        return False
    cmdline = procs[0].get('cmdline') or []
    if len(cmdline) != 1:
        return False
    return os.path.basename(cmdline[0]).lstrip('-') in ('fish', 'bash', 'zsh')


def _agent_component(window) -> str | None:
    if _at_bare_shell(window):
        return None
    uv = window.user_vars

    if uv.get('AGENT_ACTIVE') == '1':
        agent = AGENT_KIND.get(uv.get('AGENT_KIND', ''))
        if agent is None:
            return None
        state = _read_agent_state(agent, window.id) or {}
        model = state.get('model', '')
    elif uv.get('CLAUDE_ACTIVE') == '1':
        agent = 'claude'
        model = uv.get('CLAUDE_MODEL', '')
    else:
        # No user-var signal: an agent whose hooks write state through the
        # bridge but that never ran under the runner (so nothing emitted OSC).
        state = _scan_agent_state(window.id)
        if state is None:
            return None
        agent = state['agent']
        model = state.get('model', '')

    definition = AGENTS[agent]
    label = definition['label']
    short = _short_model(model)
    if short:
        label = f'{label} ({short})'
    return f' {definition["icon"]} {label}'


def _abbreviate_path(path: str) -> str:
    home = os.path.expanduser('~')
    if path == home:
        return '~'
    if path.startswith(home + '/'):
        path = '~' + path[len(home):]
    if len(path) > CWD_MAX_CHARS:
        parts = path.split('/')
        while len(parts) > 2 and len('…/' + '/'.join(parts)) > CWD_MAX_CHARS:
            parts.pop(0)
        path = '…/' + '/'.join(parts)
    return path


def _cwd_component(window) -> str | None:
    try:
        cwd = window.get_cwd_of_child() or ''
    except Exception:
        return None
    if not cwd:
        return None
    return f' 📁 {_abbreviate_path(cwd)}'


# ssh options that consume the next argument (from ssh(1)) — needed to find
# the first non-option word, the destination.
_SSH_OPTS_WITH_ARG = set('BbcDEeFIiJLlmOoPpRSWw')


def _ssh_destination(cmdline: list[str]) -> str | None:
    args = cmdline[1:]
    i = 0
    dest = None
    while i < len(args):
        a = args[i]
        if a == '--':
            dest = args[i + 1] if i + 1 < len(args) else None
            break
        if a.startswith('-') and len(a) > 1:
            if len(a) == 2 and a[1] in _SSH_OPTS_WITH_ARG:
                i += 2
            else:
                i += 1
            continue
        dest = a
        break
    if not dest:
        return None
    if dest.startswith('ssh://'):
        dest = dest[len('ssh://'):].split('/', 1)[0]
        if ':' in dest:
            dest = dest.rsplit(':', 1)[0]
    if '@' in dest:
        dest = dest.rsplit('@', 1)[1]
    return dest or None


def _ssh_component(window) -> str | None:
    try:
        procs = window.child.foreground_processes
    except Exception:
        return None
    for p in procs:
        cmdline = p.get('cmdline') or []
        if cmdline and os.path.basename(cmdline[0]) == 'ssh':
            host = _ssh_destination(cmdline)
            return f' 🔐 {host}' if host else ' 🔐 SSH'
    return None


def _summary_component(window) -> str | None:
    path = os.path.join(_runtime_root('wezterm-pane-summary'), f'pane-{_pane_key(window.id)}.json')
    try:
        with open(path) as f:
            state = json.load(f)
    except (OSError, ValueError):
        return None
    if not isinstance(state, dict) or not state.get('active'):
        return None
    updated = state.get('updatedAtMs')
    if not isinstance(updated, (int, float)) or (time.time() * 1000) - updated > SUMMARY_TTL_MS:
        return None
    if state.get('confidence') not in ('medium', 'high'):
        return None
    summary = state.get('summary')
    if not isinstance(summary, str):
        return None
    summary = ' '.join(summary.split())
    if not summary:
        return None
    if len(summary) > SUMMARY_MAX_CHARS:
        summary = summary[:SUMMARY_MAX_CHARS - 1] + '…'
    return f' {summary}'


def _components(window) -> list[str]:
    # Headers are for harness/SSH windows only: a plain interactive shell gets
    # no header — cwd, model, and summary are all things the human at the
    # keyboard already knows there. cwd and summary render only next to an
    # agent component.
    parts = []
    ssh = _ssh_component(window)
    if ssh:
        parts.append(ssh)
    agent = _agent_component(window)
    if agent:
        parts.append(agent)
        cwd = _cwd_component(window)
        if cwd:
            parts.append(cwd)
        summary = _summary_component(window)
        if summary:
            parts.append(summary)
    return parts


def _content_present(boss) -> bool:
    for tm in boss.os_window_map.values():
        for tab in tm:
            w = tab.active_window
            if w is not None and _components(w):
                return True
    return False


_DEBUG = os.environ.get('KITTY_HEADER_DEBUG') == '1'


def _dbg(msg: str) -> None:
    if _DEBUG:
        import sys
        print(f'[header] {msg}', file=sys.stderr, flush=True)


def check_visibility() -> None:
    # Hide the bar when the header is empty. tab_bar_min_tabs drives the C
    # layout, so mutate the live Options and push it with the same call the
    # config-reload path uses (apply_new_options in boss.py).
    boss = get_boss()
    opts = get_options()
    want = 1 if _content_present(boss) else 9999
    _dbg(f'check: min_tabs={opts.tab_bar_min_tabs} want={want}')
    if opts.tab_bar_min_tabs != want:
        opts.tab_bar_min_tabs = want
        # apply_options_update() is not enough: the tab bar's screen space is
        # computed in C from its own copy of the options, and only a full
        # set_options push (the same call boss.apply_new_options makes on
        # config reload) refreshes it. Same Options object, one changed field.
        set_options(opts, is_wayland(), boss.args.debug_rendering, boss.args.debug_font_fallback)
        for tm in boss.os_window_map.values():
            tm.tabbar_visibility_changed()
        _dbg('visibility flipped')
    for tm in boss.os_window_map.values():
        tm.mark_tab_bar_dirty()


_timer_id = None


def _tick(timer_id=None) -> None:
    check_visibility()


def _ensure_timer() -> None:
    # Periodic refresh so SSH transitions, state-file TTL expiry, and
    # visibility changes show up without user-var events (mirrors wezterm's
    # status_update_interval). Runs even while the bar is hidden.
    global _timer_id
    if _timer_id is None:
        _timer_id = add_timer(_tick, 2.0, True)
        _dbg(f'timer installed id={_timer_id}')


# The bar starts hidden (tab_bar_min_tabs 9999 in kitty.conf), so draw_tab —
# the usual timer bootstrap — may never run. This module is imported during
# TabBar creation at startup, so install the timer here; guarded in case a
# future kitty constructs TabBar before its event loop exists.
try:
    _ensure_timer()
except Exception:
    pass


def _tab_window(tab_id: int):
    boss = get_boss()
    for tm in boss.os_window_map.values():
        for tab in tm:
            if tab.id == tab_id:
                return tab.active_window
    return None


def draw_tab(
    draw_data: DrawData, screen: Screen, tab: TabBarData,
    before: int, max_tab_length: int, index: int, is_last: bool,
    extra_data: ExtraData,
) -> int:
    _ensure_timer()

    if index != 1:
        return screen.cursor.x

    window = _tab_window(tab.tab_id)
    components = _components(window) if window is not None else []

    screen.cursor.bg = as_rgb(color_as_int(draw_data.default_bg))
    screen.cursor.fg = as_rgb(color_as_int(draw_data.inactive_fg))
    if components:
        screen.draw(' | '.join(components) + ' ')
    return screen.cursor.x

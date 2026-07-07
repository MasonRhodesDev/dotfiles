# Custom tab bar — port of the wezterm headerModules system.
# Renders a left status line per OS window instead of tab titles:
#   [🔐 SSH] [🤖 Claude (opus) ...]
# Modules: ssh (priority 0), agent (priority 1). Pane-summary module was
# deliberately not ported.
#
# The bar hides entirely when it has no content: a 2s timer (and the
# on_set_user_var watcher) flips tab_bar_min_tabs between 1 and 9999 and
# relayouts. Visibility is per kitty instance — one instance per OS window
# under Hyprland, so per-window in practice.
#
# State protocol shared with wezterm (written by ~/scripts/wezterm-agent-*):
#   $XDG_RUNTIME_DIR/wezterm-agent-status/<agent>/pane-<key>.json
# where <key> is "kitty-$KITTY_WINDOW_ID" for kitty windows. Unlike the
# wezterm build, kitty accepts string SetUserVar values, so the legacy
# CLAUDE_* vars carry their payload directly.

import json
import os
import time

from kitty.boss import get_boss
from kitty.constants import is_wayland
from kitty.fast_data_types import Screen, add_timer, get_options, set_options
from kitty.tab_bar import DrawData, ExtraData, TabBarData, as_rgb
from kitty.utils import color_as_int

STATE_TTL_MS = 2 * 60 * 1000

AGENTS = {
    'claude': {'label': 'Claude', 'icon': '🤖'},
    'codex': {'label': 'Codex', 'icon': '✦'},
    'pi': {'label': 'Pi', 'icon': 'π'},
}

AGENT_KIND = {'1': 'pi', '2': 'codex', '3': 'claude'}


def _runtime_root(name: str) -> str:
    base = os.environ.get('XDG_RUNTIME_DIR') or os.path.join(os.environ.get('HOME', '.'), '.cache')
    return os.path.join(base, name)


def _short_model(model: str) -> str:
    if not model:
        return ''
    for m in ('opus', 'sonnet', 'haiku', 'fable'):
        if m in model:
            return m
    return model.removeprefix('amazon-bedrock/')


def _read_agent_state(agent: str, window_id: int):
    path = os.path.join(_runtime_root('wezterm-agent-status'), agent, f'pane-kitty-{window_id}.json')
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


def _agent_component(window) -> str | None:
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
        return None

    definition = AGENTS[agent]
    label = definition['label']
    short = _short_model(model)
    if short:
        label = f'{label} ({short})'
    return f' {definition["icon"]} {label}'


def _ssh_component(window) -> str | None:
    try:
        procs = window.child.foreground_processes
    except Exception:
        return None
    for p in procs:
        cmdline = p.get('cmdline') or []
        if cmdline and os.path.basename(cmdline[0]) == 'ssh':
            return ' 🔐 SSH'
    return None


def _components(window) -> list[str]:
    parts = []
    ssh = _ssh_component(window)
    if ssh:
        parts.append(ssh)
    agent = _agent_component(window)
    if agent:
        parts.append(agent)
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

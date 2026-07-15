# Dumb renderer for the terminal-header daemon (~/scripts/terminal-header/).
# All header policy — sections, ordering, agent detection, summaries — lives
# in the daemon, which writes $XDG_RUNTIME_DIR/terminal-header/pane-<key>.json
# as {"header": string|null, "updatedAtMs": ms}. This module reads that file,
# draws the string, and flips the bar's visibility. Pane key is
# kitty-<kitty pid>-<window id> (the pid disambiguates instances: Hyprland
# runs one kitty per OS window, so window ids alone collide).
#
# The only policy kept in-process is the visibility flip itself, which must
# run inside kitty: tab_bar_min_tabs drives the C layout, and a 2s timer (plus
# the on_set_user_var watcher) flips it between 1 and 9999.

import json
import os
import time

from kitty.boss import get_boss
from kitty.constants import is_wayland
from kitty.fast_data_types import Screen, add_timer, get_options, set_options
from kitty.tab_bar import DrawData, ExtraData, TabBarData, as_rgb
from kitty.utils import color_as_int

HEADER_TTL_MS = 60 * 1000


def _runtime_root(name: str) -> str:
    base = os.environ.get('XDG_RUNTIME_DIR') or os.path.join(os.environ.get('HOME', '.'), '.cache')
    return os.path.join(base, name)


def _header_for(window_id: int) -> str | None:
    path = os.path.join(_runtime_root('terminal-header'), f'pane-kitty-{os.getpid()}-{window_id}.json')
    try:
        with open(path) as f:
            state = json.load(f)
    except (OSError, ValueError) as e:
        _dbg(f'header miss {path}: {e.__class__.__name__}')
        return None
    if not isinstance(state, dict):
        return None
    header = state.get('header')
    if not isinstance(header, str) or not header:
        return None
    updated = state.get('updatedAtMs')
    if not isinstance(updated, (int, float)) or (time.time() * 1000) - updated > HEADER_TTL_MS:
        _dbg(f'header stale {path}')
        return None
    return header


def _content_present(boss) -> bool:
    for tm in boss.os_window_map.values():
        for tab in tm:
            w = tab.active_window
            if w is not None and _header_for(w.id):
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
        set_options(opts, is_wayland(), boss.args.debug_rendering, boss.args.debug_font_fallback)
        for tm in boss.os_window_map.values():
            legacy_relayout = getattr(tm, 'tabbar_visibility_changed', None)
            if legacy_relayout is not None:
                # kitty < 0.47
                legacy_relayout()
            else:
                # kitty >= 0.47: mirror the update_tab_bar_visibility
                # decorator in tabs.py — relayout the bar, then the tabs.
                if not tm.tab_bar_hidden:
                    tm.layout_tab_bar()
                tm.resize(only_tabs=True)
        _dbg('visibility flipped')
    for tm in boss.os_window_map.values():
        tm.mark_tab_bar_dirty()


_timer_id = None


def _tick(timer_id=None) -> None:
    check_visibility()


def _ensure_timer() -> None:
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
    header = _header_for(window.id) if window is not None else None

    screen.cursor.bg = as_rgb(color_as_int(draw_data.default_bg))
    screen.cursor.fg = as_rgb(color_as_int(draw_data.inactive_fg))
    if header:
        screen.draw(f' {header} ')
    return screen.cursor.x

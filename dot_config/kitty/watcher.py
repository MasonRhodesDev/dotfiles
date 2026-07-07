# Event-driven header refresh: agent hooks set user vars via OSC 1337
# SetUserVar; re-evaluate header visibility and redraw immediately instead
# of waiting for the 2s timer in tab_bar.py (mirrors wezterm's
# user-var-changed → invalidate flow; the check is cheap).

import importlib.util
import os
from typing import Any

from kitty.boss import Boss
from kitty.window import Window

_tab_bar_module = None


def _tab_bar():
    global _tab_bar_module
    if _tab_bar_module is None:
        path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'tab_bar.py')
        spec = importlib.util.spec_from_file_location('lmtt_header_tab_bar', path)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        _tab_bar_module = mod
    return _tab_bar_module


def on_set_user_var(boss: Boss, window: Window, data: dict[str, Any]) -> None:
    try:
        _tab_bar().check_visibility()
    except Exception:
        tab = window.tabref()
        if tab is not None:
            tab.mark_tab_bar_dirty()

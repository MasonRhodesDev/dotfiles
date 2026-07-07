# Smart paste kitten — parity with the wezterm Ctrl+V action_callback:
# runs wezterm-paste-image, which returns a temp-file path for image
# clipboard contents or the plain text otherwise, and pastes the result.

import subprocess

from kittens.tui.handler import result_handler


def main(args: list[str]) -> str:
    return ''


@result_handler(no_ui=True)
def handle_result(args: list[str], answer: str, target_window_id: int, boss) -> None:
    window = boss.window_id_map.get(target_window_id)
    if window is None:
        return
    try:
        out = subprocess.run(
            ['/home/mason/scripts/wezterm-paste-image'],
            capture_output=True, text=True, timeout=10,
        ).stdout
    except Exception:
        return
    if out:
        window.paste_text(out)

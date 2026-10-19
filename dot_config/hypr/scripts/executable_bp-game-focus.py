#!/usr/bin/env python3
"""Steam side-car for the Big Picture / game session. NOT a window manager.

The window/focus state machine that used to live here is now config:
~/.config/hypr/bp-focus.lua. It had to move. This daemon drove Hyprland with
pre-Lua dispatcher strings such as

    hyprctl dispatch focuswindow address:0x...
    hyprctl dispatch fullscreen 0
    hyprctl dispatch togglespecialworkspace magic

and since the Lua config migration `hyprctl dispatch` EVALUATES ITS ARGUMENT
AS LUA, so every one of those has failed with exit 7 ("')' expected near
'address'") into a log nobody reads. The daemon focused nothing, fullscreened
nothing and dismissed no special workspace for months, which is why Big Picture
kept losing the screen to special:magic and why Steam in-home streaming kept
capturing the Big Picture window instead of the game. Hyprland's Lua API has
window.open / window.active / workspace.special_active / window.update_rules
events, timers and dispatchers, so none of that needed a process at all.

What genuinely cannot be config, and is all that is left here:

  - Gamepad guide button (BTN_MODE) via evdev, with bluetooth hotplug. Lua has
    no access to input devices. A press calls BP_FOCUS.guide() and nothing
    else; where to go, including launching Big Picture when there is nothing
    to go to, is decided there.
  - SIGUSR1 simulates a guide press (testing / keyboard binds).
  - Steam's CEF log: detect GPU-process crash storms and cleanly restart Steam.
  - Steam's webhelper wrapper: re-apply --disable-gpu-process-crash-limit,
    which Steam overwrites on client updates.
  - Steam's Remote Play log: Lua has no file watch, so the session boundary
    lines are tailed here and handed to BP_FOCUS.stream_event(live). The two
    marker strings are bp-focus.lua's; this file only forwards the edge.
    (Steam asks for the foreground itself exactly once, ~3 seconds BEFORE the
    game's window exists: "Bringing streamed game to foreground - failed",
    every time it was logged.)

Every Hyprland interaction goes through `hyprctl eval` into bp-focus.lua, so
there is one owner of focus policy and it is the same Lua the config uses.
Read-only `hyprctl -j` queries are still used directly; those never broke.
"""

import asyncio
import json
import os
import re
import signal
import subprocess
import time
from collections import deque

import evdev

RUNTIME = os.environ["XDG_RUNTIME_DIR"]
SOCKET2 = "{}/hypr/{}/.socket2.sock".format(
    RUNTIME, os.environ["HYPRLAND_INSTANCE_SIGNATURE"]
)
LOG_PATH = f"{RUNTIME}/bp-game-focus.log"

BTN_MODE = evdev.ecodes.BTN_MODE  # 316: Xbox guide / PS button
GUIDE_COOLDOWN = 0.4  # s; dedups physical + Steam-virtual-pad double reports

STEAM_HOME = os.path.expanduser("~/.local/share/Steam")
CEF_LOG = f"{STEAM_HOME}/logs/cef_log.txt"
STREAM_LOG = f"{STEAM_HOME}/logs/streaming_log.txt"
# Steam launches the webhelper through this wrapper; appending the flag here is
# the one point that reliably reaches CEF (Steam doesn't forward arbitrary
# -cef-* args). Steam rewrites the file on client updates, so we re-patch it.
WEBHELPER_WRAP = f"{STEAM_HOME}/ubuntu12_64/steamwebhelper_sniper_wrap.sh"
CEF_RECOVER_FLAG = "--disable-gpu-process-crash-limit"
# The one definition of how Steam is launched; local.lua's autostart and
# bp-focus.lua's guide handling use the same script.
STEAM_LAUNCH = os.path.expanduser("~/.local/bin/steam-launch")
STEAM_SHUTDOWN = os.path.expanduser("~/.config/hypr/scripts/steam-clean-shutdown.sh")
# GPU-crash storm -> clean restart (only when no game is running)
CRASH_WINDOW = 45.0  # s; sliding window for counting GPU-process crashes
CRASH_LIMIT = 3  # crashes within CRASH_WINDOW that trigger a recovery restart
RESTART_DEBOUNCE = 300.0  # s; never auto-restart more often than this

# Steam brackets every SESSION with these two lines, paired 1:1 with client
# connections. They are the markers bp-focus.lua's streaming() reads; see its
# comment for why the per-source ">>> Starting/Stopped desktop stream" lines
# and any freshness window are wrong.
STREAM_START = "Streaming started to "
STREAM_STOP = "PipeWire: Deinitializing streaming"

_log_file = open(LOG_PATH, "w", buffering=1)


def log(msg: str) -> None:
    _log_file.write(f"{time.strftime('%H:%M:%S')} {msg}\n")


def hyprctl(*args: str) -> str:
    p = subprocess.run(["hyprctl", *args], capture_output=True, text=True)
    if p.returncode != 0:
        log(f"hyprctl {' '.join(args)} failed ({p.returncode}): {p.stderr.strip()}")
    return p.stdout


def lua(expr: str) -> None:
    """Run Lua in Hyprland. The ONLY way this daemon touches the compositor.

    `hyprctl eval` gives no return value back, so nothing here reads state out
    of Lua, so read-only decisions use the -j queries below instead.

    Reports failure on EVERY channel: Lua errors come back as `error: ...` and
    land on stderr, and `eval`'s exit code for a failed chunk is not something
    to rely on. The whole reason this file shrank is that its predecessor's
    compositor calls failed into a void, and a silent `lua()` would rebuild that
    trap in one line.
    """
    p = subprocess.run(["hyprctl", "eval", expr], capture_output=True, text=True)
    err = (p.stderr or "").strip()
    out = (p.stdout or "").strip()
    if p.returncode != 0 or err or "error" in out.lower():
        log(f"lua FAILED rc={p.returncode} {expr} -> out={out!r} err={err!r}")


def clients() -> list:
    return json.loads(hyprctl("clients", "-j") or "[]")


GAME_CLASS = re.compile(r"^steam_app_\d+$")


def game_running() -> bool:
    """The ONE guard that still needs a window list here: never restart Steam
    out from under a running game. Deliberately cruder than bp-focus.lua's
    is_game (Steam's own app classes only); a missed exotic class means a
    skipped restart, which costs nothing."""
    return any(GAME_CLASS.match(c.get("class", "")) for c in clients())


def ensure_webhelper_patch() -> None:
    """Re-add CEF_RECOVER_FLAG to Steam's webhelper wrapper if missing.
    Steam overwrites this file on client updates, so the daemon re-applies it
    on startup. Takes effect on the next Steam (re)launch, not retroactively."""
    try:
        with open(WEBHELPER_WRAP) as f:
            content = f.read()
    except OSError:
        return  # Steam not installed where we expect; nothing to do
    if CEF_RECOVER_FLAG in content:
        return
    target = 'exec ./steamwebhelper "$@"'
    if target not in content:
        log("webhelper patch: exec line not found, skipping")
        return
    try:
        with open(WEBHELPER_WRAP, "w") as f:
            f.write(content.replace(target, f"{target} {CEF_RECOVER_FLAG}"))
        log("webhelper patch: re-applied crash-limit flag (effective next launch)")
    except OSError as e:
        log(f"webhelper patch failed: {e}")


def restart_steam(reason: str) -> None:
    """Clean-shutdown + relaunch Steam, detached so it survives this daemon.
    Used to recover from a CEF GPU-crash storm that left BP in software."""
    log(f"auto-recover: restarting Steam ({reason})")
    script = (
        f"{STEAM_SHUTDOWN}; "
        "pgrep -x steam >/dev/null && { pkill -x steam; sleep 2; }; "
        f"{STEAM_LAUNCH}"
    )
    subprocess.Popen(
        ["bash", "-c", script],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )


class Guide:
    """Guide-button handling. Focus policy itself lives in bp-focus.lua."""

    def __init__(self) -> None:
        self._last = 0.0

    def press(self) -> None:
        now = time.monotonic()
        if now - self._last < GUIDE_COOLDOWN:
            return
        self._last = now

        log("guide -> BP_FOCUS.guide()")
        lua("BP_FOCUS.guide()")


# --- inputs ----------------------------------------------------------------


async def hypr_lifetime() -> None:
    """Hold socket2 open purely as a lifetime signal: when Hyprland exits, the
    socket closes and so do we. Events are no longer parsed here because bp-focus.lua
    gets them in-process, which is the whole point of the move.

    NOTE: the writer must stay referenced for the life of the loop, because if it is
    garbage collected, StreamWriter.__del__ closes the transport and the reader
    sees EOF (bit us on Python 3.14).
    """
    reader, writer = await asyncio.open_unix_connection(SOCKET2)
    try:
        while await reader.readline():
            pass
    finally:
        writer.close()
    log("Hyprland socket closed, exiting")


async def watch_gamepad(guide: Guide, dev: evdev.InputDevice, watched: set) -> None:
    try:
        async for ev in dev.async_read_loop():
            if ev.type == evdev.ecodes.EV_KEY and ev.code == BTN_MODE and ev.value == 1:
                log(f"guide press from {dev.name}")
                guide.press()
    except OSError:
        log(f"gamepad disconnected: {dev.name}")
    finally:
        watched.discard(dev.path)
        try:
            dev.close()
        except OSError:
            pass


async def gamepad_scanner(guide: Guide) -> None:
    """Watch every device exposing BTN_MODE; rescan for bluetooth hotplug."""
    watched: set[str] = set()
    while True:
        for path in evdev.list_devices():
            if path in watched:
                continue
            try:
                dev = evdev.InputDevice(path)
                if BTN_MODE in dev.capabilities().get(evdev.ecodes.EV_KEY, []):
                    watched.add(path)
                    log(f"watching gamepad: {dev.name} ({path})")
                    asyncio.create_task(watch_gamepad(guide, dev, watched))
                else:
                    dev.close()
            except OSError:
                pass
        await asyncio.sleep(3)


async def tail(path: str, on_line, retry: float = 2.0) -> None:
    """Follow a Steam log across rotation/truncation, calling on_line(str)."""
    f = None
    inode = None
    while True:
        try:
            if f is None:
                f = open(path)
                st_ino = os.fstat(f.fileno()).st_ino
                if inode is None or st_ino == inode:
                    # First open (ignore pre-existing history) or reopen of the
                    # same file after a transient error (avoid double-counting).
                    f.seek(0, 2)
                # else: rotated/recreated file, so read from 0 so lines written
                # between rotation and reopen aren't missed.
                inode = st_ino
            line = f.readline()
            if not line:
                st = os.stat(path)
                if st.st_ino != inode or st.st_size < f.tell():
                    f.close()
                    f = None
                    continue
                await asyncio.sleep(1.0)
                continue
            on_line(line)
        except FileNotFoundError:
            f = None
            await asyncio.sleep(retry)
        except OSError as e:
            log(f"tail {path}: {e}")
            if f is not None:
                f.close()
            f = None
            await asyncio.sleep(retry)


async def cef_log_watch() -> None:
    """Tail Steam's CEF log; on a GPU-process crash storm with no game running,
    cleanly restart Steam. With CEF_RECOVER_FLAG a lone crash self-heals, so
    this only fires when CEF can't recover (repeated crashes in a short span)."""
    crashes: deque[float] = deque()
    state = {"last_restart": 0.0}

    def on_line(line: str) -> None:
        if "GPU process exited unexpectedly" not in line:
            return
        now = time.monotonic()
        crashes.append(now)
        while crashes and now - crashes[0] > CRASH_WINDOW:
            crashes.popleft()
        log(f"CEF GPU crash detected ({len(crashes)} within {int(CRASH_WINDOW)}s)")
        if (
            len(crashes) >= CRASH_LIMIT
            and not game_running()
            and now - state["last_restart"] > RESTART_DEBOUNCE
        ):
            state["last_restart"] = now
            crashes.clear()
            restart_steam(f"{CRASH_LIMIT} GPU crashes within {int(CRASH_WINDOW)}s")

    await tail(CEF_LOG, on_line)


async def webhelper_watch() -> None:
    """Steam has been seen rewriting the wrapper from its package mid-session,
    reverting our flag, so re-assert it periodically."""
    while True:
        await asyncio.sleep(120)
        ensure_webhelper_patch()


async def stream_watch() -> None:
    """Forward each Remote Play session boundary to bp-focus.lua. Only the
    edges are reported; what they mean is the Lua module's business."""

    def on_line(line: str) -> None:
        if STREAM_START in line:
            log("stream session started -> BP_FOCUS.stream_event(true)")
            lua("BP_FOCUS.stream_event(true)")
        elif STREAM_STOP in line:
            log("stream session ended -> BP_FOCUS.stream_event(false)")
            lua("BP_FOCUS.stream_event(false)")

    await tail(STREAM_LOG, on_line)


async def main() -> None:
    ensure_webhelper_patch()
    guide = Guide()
    asyncio.get_running_loop().add_signal_handler(signal.SIGUSR1, guide.press)
    tasks = [
        asyncio.create_task(gamepad_scanner(guide)),
        asyncio.create_task(cef_log_watch()),
        asyncio.create_task(webhelper_watch()),
        asyncio.create_task(stream_watch()),
    ]
    log("started: guide button + Steam log chores; focus policy = bp-focus.lua")
    await hypr_lifetime()  # returns when Hyprland exits
    for t in tasks:
        t.cancel()


if __name__ == "__main__":
    asyncio.run(main())

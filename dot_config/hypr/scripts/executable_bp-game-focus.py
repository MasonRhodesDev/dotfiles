#!/usr/bin/env python3

import asyncio
import ctypes
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

BTN_MODE = evdev.ecodes.BTN_MODE
GUIDE_COOLDOWN = 0.4

STEAM_HOME = os.path.expanduser("~/.local/share/Steam")
CEF_LOG = f"{STEAM_HOME}/logs/cef_log.txt"
STREAM_LOG = f"{STEAM_HOME}/logs/streaming_log.txt"
WEBHELPER_WRAP = f"{STEAM_HOME}/ubuntu12_64/steamwebhelper_sniper_wrap.sh"
CEF_RECOVER_FLAG = "--disable-gpu-process-crash-limit"
STEAM_LAUNCH = os.path.expanduser("~/.local/bin/steam-launch")
STEAM_SHUTDOWN = os.path.expanduser("~/.config/hypr/scripts/steam-clean-shutdown.sh")
CRASH_WINDOW = 45.0
CRASH_LIMIT = 3
RESTART_DEBOUNCE = 300.0

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
    p = subprocess.run(["hyprctl", "eval", expr], capture_output=True, text=True)
    err = (p.stderr or "").strip()
    out = (p.stdout or "").strip()
    if p.returncode != 0 or err or "error" in out.lower():
        log(f"lua FAILED rc={p.returncode} {expr} -> out={out!r} err={err!r}")


def clients() -> list:
    return json.loads(hyprctl("clients", "-j") or "[]")


GAME_CLASS = re.compile(r"^steam_app_\d+$")


def game_running() -> bool:
    return any(GAME_CLASS.match(c.get("class", "")) for c in clients())


def ensure_webhelper_patch() -> None:
    try:
        with open(WEBHELPER_WRAP) as f:
            content = f.read()
    except OSError:
        return
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
    log(f"auto-recover: restarting Steam ({reason})")
    lua("if BP_MONITORS then BP_MONITORS.hold(true) end")
    script = (
        "trap \"hyprctl eval 'if BP_MONITORS then BP_MONITORS.hold(false) end' >/dev/null 2>&1\" EXIT; "
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
    def __init__(self) -> None:
        self._last = 0.0

    def press(self) -> None:
        now = time.monotonic()
        if now - self._last < GUIDE_COOLDOWN:
            return
        self._last = now

        log("guide -> BP_FOCUS.guide()")
        lua("BP_FOCUS.guide()")



async def hypr_lifetime() -> None:
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


class DirWatch:
    IN_MODIFY, IN_CREATE, IN_MOVED_FROM, IN_MOVED_TO, IN_DELETE = 0x2, 0x100, 0x40, 0x80, 0x200
    IN_NONBLOCK, IN_CLOEXEC = 0o4000, 0o2000000
    _watches: dict[str, "DirWatch"] = {}

    @classmethod
    def for_dir(cls, path: str) -> "DirWatch":
        w = cls._watches.get(path)
        if w is None:
            w = cls._watches[path] = cls(path)
        return w

    def __init__(self, path: str) -> None:
        self.changed = asyncio.Event()
        self.fd = -1
        try:
            libc = ctypes.CDLL(None, use_errno=True)
            fd = libc.inotify_init1(self.IN_NONBLOCK | self.IN_CLOEXEC)
            if fd < 0:
                raise OSError(ctypes.get_errno(), "inotify_init1")
            mask = self.IN_MODIFY | self.IN_CREATE | self.IN_MOVED_FROM | self.IN_MOVED_TO | self.IN_DELETE
            if libc.inotify_add_watch(fd, path.encode(), mask) < 0:
                os.close(fd)
                raise OSError(ctypes.get_errno(), "inotify_add_watch")
            self.fd = fd
            asyncio.get_running_loop().add_reader(fd, self._readable)
        except OSError as e:
            log(f"inotify unavailable for {path} ({e}); tails fall back to 1s polling")

    def _readable(self) -> None:
        try:
            os.read(self.fd, 65536)
        except BlockingIOError:
            pass
        self.changed.set()

    async def wait(self) -> None:
        if self.fd < 0:
            await asyncio.sleep(1.0)
            return
        self.changed.clear()
        await self.changed.wait()


async def tail(path: str, on_line, retry: float = 2.0) -> None:
    f = None
    inode = None
    watch = DirWatch.for_dir(os.path.dirname(path))
    while True:
        try:
            if f is None:
                f = open(path)
                st_ino = os.fstat(f.fileno()).st_ino
                if inode is None or st_ino == inode:
                    f.seek(0, 2)
                inode = st_ino
            line = f.readline()
            if not line:
                st = os.stat(path)
                if st.st_ino != inode or st.st_size < f.tell():
                    f.close()
                    f = None
                    continue
                await watch.wait()
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
    while True:
        await asyncio.sleep(120)
        ensure_webhelper_patch()


async def stream_watch() -> None:
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
    await hypr_lifetime()
    for t in tasks:
        t.cancel()


if __name__ == "__main__":
    asyncio.run(main())

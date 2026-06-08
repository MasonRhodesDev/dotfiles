#!/usr/bin/env python3
"""Steam Big Picture / game session state machine for Hyprland.

States (derived from the active window):
  DESKTOP - normal desktop use. Game windows opening here load in the
            background (rules.conf blocks their initial focus).
  BP      - Big Picture is the active window. Kept fullscreen at all times.
  GAME    - a game window is active. Game windows opening here steal focus
            and are fullscreened (covers splash -> main window chains).

Inputs:
  - Hyprland socket2 events: openwindow / closewindow / activewindowv2 /
    fullscreen
  - Gamepad guide button (BTN_MODE) via evdev, with bluetooth hotplug:
      press -> focus newest game window; else focus Big Picture; else focus
      the Steam desktop window; else launch Big Picture
  - SIGUSR1 simulates a guide press (for testing / keyboard binds)

rules.conf keeps no_initial_focus/focus_on_activate off on game windows and
focus_on_activate off on Big Picture; this daemon is the only thing moving
focus between them.
"""

import asyncio
import json
import os
import signal
import subprocess
import time

import evdev

RUNTIME = os.environ["XDG_RUNTIME_DIR"]
SOCKET2 = "{}/hypr/{}/.socket2.sock".format(
    RUNTIME, os.environ["HYPRLAND_INSTANCE_SIGNATURE"]
)
LOG_PATH = f"{RUNTIME}/bp-game-focus.log"

BP_TITLE = "Steam Big Picture Mode"
BTN_MODE = evdev.ecodes.BTN_MODE  # 316: Xbox guide / PS button
GUIDE_COOLDOWN = 0.4  # s; dedups physical + Steam-virtual-pad double reports
FULLSCREEN_GRACE = 0.3  # s; let a game self-fullscreen before we force it

_log_file = open(LOG_PATH, "w", buffering=1)


def log(msg: str) -> None:
    _log_file.write(f"{time.strftime('%H:%M:%S')} {msg}\n")


def hyprctl(*args: str) -> str:
    return subprocess.run(
        ["hyprctl", *args], capture_output=True, text=True
    ).stdout


def clients() -> list:
    return json.loads(hyprctl("clients", "-j") or "[]")


def active_window() -> dict:
    out = hyprctl("activewindow", "-j").strip()
    return json.loads(out) if out.startswith("{") else {}


def window_workspace(addr: str) -> str | None:
    return next(
        (c["workspace"]["name"] for c in clients() if c["address"] == addr), None
    )


def close_special_except(keep: str | None) -> None:
    """Toggle off any special workspace shown on a monitor, except `keep`.
    focuswindow switches the base workspace under the target but leaves a
    special overlay (e.g. special:magic) toggled on top — close it so guiding
    to a game/BP on a regular workspace actually leaves the special workspace."""
    for mon in json.loads(hyprctl("monitors", "-j") or "[]"):
        name = mon.get("specialWorkspace", {}).get("name", "")
        if name and name != keep:
            log(f"closing special workspace {name}")
            hyprctl("dispatch", "togglespecialworkspace", name.removeprefix("special:"))


LAUNCHER_CLASSES = {"org.prismlauncher.PrismLauncher"}  # Steam-launched, but not games


def window_pid(addr: str) -> int | None:
    return next((c["pid"] for c in clients() if c["address"] == addr), None)


def under_steam_launch(pid: int | None) -> bool:
    """True if the process hangs off Steam's `reaper SteamLaunch AppId=N`
    wrapper — i.e. Steam launched it (Steam game or non-Steam shortcut).
    Steam's own UI (steamwebhelper etc.) is a child of steam but never of
    reaper, so it never matches."""
    for _ in range(40):  # ancestry depth guard
        if not pid or pid <= 1:
            return False
        try:
            with open(f"/proc/{pid}/cmdline", "rb") as f:
                if b"SteamLaunch" in f.read():
                    return True
            with open(f"/proc/{pid}/stat") as f:
                stat = f.read()
        except OSError:  # process exited mid-walk
            return False
        pid = int(stat.rpartition(")")[2].split()[1])  # ppid
    return False


def is_game(cls: str, title: str, pid: int | None = None) -> bool:
    """Class/title set from the game rules in rules.conf, plus anything whose
    process tree hangs off Steam's launch reaper (catches native games that
    set their own window class, e.g. Minecraft via Prism)."""
    if cls in LAUNCHER_CLASSES or cls == "steam":
        return False
    if cls.startswith("steam_app_") or cls == "gamescope" or title == "Godot":
        return True
    return under_steam_launch(pid)


class SteamSession:
    DESKTOP, BP, GAME = "DESKTOP", "BP", "GAME"

    def __init__(self) -> None:
        self.state = self.DESKTOP
        self.bp_addr: str | None = None
        self.games: dict[str, str] = {}  # addr -> class, newest last
        self._last_guide = 0.0
        self.resync()

    def resync(self) -> None:
        """Rebuild window tracking from hyprctl (daemon may start late)."""
        self.bp_addr = None
        self.games.clear()
        for c in clients():
            if c["class"] == "steam" and c["title"] == BP_TITLE:
                self.bp_addr = c["address"]
            elif is_game(c["class"], c["title"], c["pid"]):
                self.games[c["address"]] = c["class"]
        self.on_active(active_window().get("address"))
        log(f"resync: state={self.state} bp={self.bp_addr} games={list(self.games)}")

    # --- transitions -------------------------------------------------------

    def on_open(self, addr: str, cls: str, title: str) -> None:
        if cls == "steam" and title == BP_TITLE:
            self.bp_addr = addr  # rules.conf already fullscreens it on ws 7
            log(f"BP opened: {addr}")
        elif is_game(cls, title, window_pid(addr)):
            self.games[addr] = cls
            if self.state in (self.BP, self.GAME):
                log(f"game {cls} opened in {self.state} -> steal focus")
                asyncio.create_task(self.focus_fullscreen(addr))
            else:
                log(f"game {cls} opened on {self.state} -> background")

    def on_close(self, addr: str) -> None:
        if addr == self.bp_addr:
            self.bp_addr = None
            log("BP closed")
        elif self.games.pop(addr, None):
            log(f"game closed: {addr}")

    def on_active(self, addr: str | None) -> None:
        prev = self.state
        if addr and addr == self.bp_addr:
            self.state = self.BP
            self.ensure_bp_fullscreen()
        elif addr in self.games:
            self.state = self.GAME
        else:
            self.state = self.DESKTOP
        if self.state != prev:
            log(f"state: {prev} -> {self.state}")

    def on_fullscreen(self, flag: str) -> None:
        if flag == "0" and self.state == self.BP:
            self.ensure_bp_fullscreen()

    def on_guide(self) -> None:
        now = time.monotonic()
        if now - self._last_guide < GUIDE_COOLDOWN:
            return
        self._last_guide = now

        if self.games:
            addr = next(reversed(self.games))  # newest game window
            log(f"guide -> focus game {self.games[addr]}")
            asyncio.create_task(self.focus_fullscreen(addr))
        elif self.bp_addr:
            log("guide -> focus Big Picture")
            hyprctl("dispatch", "focuswindow", f"address:{self.bp_addr}")
            close_special_except(window_workspace(self.bp_addr))
        else:
            steam = next((c for c in clients() if c["class"] == "steam"), None)
            if steam:
                log("guide -> focus Steam desktop window")
                hyprctl("dispatch", "focuswindow", f"address:{steam['address']}")
            else:
                log("guide -> no Steam window, launching Big Picture")
                subprocess.Popen(
                    ["uwsm", "app", "--", "steam", "steam://open/bigpicture"],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )

    # --- actions -----------------------------------------------------------

    async def focus_fullscreen(self, addr: str) -> None:
        hyprctl("dispatch", "focuswindow", f"address:{addr}")
        close_special_except(window_workspace(addr))
        await asyncio.sleep(FULLSCREEN_GRACE)
        aw = active_window()
        if aw.get("address") == addr and aw.get("fullscreen") != 2:
            hyprctl("dispatch", "fullscreen", "0")

    def ensure_bp_fullscreen(self) -> None:
        aw = active_window()
        if aw.get("address") == self.bp_addr and aw.get("fullscreen") != 2:
            log("re-fullscreening Big Picture")
            hyprctl("dispatch", "fullscreen", "0")


# --- inputs ----------------------------------------------------------------


async def hypr_events(sm: SteamSession) -> None:
    # NOTE: the writer must stay referenced for the life of the loop — if it is
    # garbage collected, StreamWriter.__del__ closes the transport and the
    # reader sees EOF (bit us on Python 3.14).
    reader, writer = await asyncio.open_unix_connection(SOCKET2)
    try:
        await _read_events(reader, sm)
    finally:
        writer.close()


async def _read_events(reader: asyncio.StreamReader, sm: SteamSession) -> None:
    while line := await reader.readline():
        event, _, data = line.decode(errors="replace").rstrip("\n").partition(">>")
        if event == "openwindow":
            addr, _, rest = data.partition(",")
            _ws, _, rest = rest.partition(",")
            cls, _, title = rest.partition(",")
            sm.on_open("0x" + addr, cls, title)
        elif event == "closewindow":
            sm.on_close("0x" + data)
        elif event == "activewindowv2":
            sm.on_active("0x" + data if data else None)
        elif event == "fullscreen":
            sm.on_fullscreen(data)
    log("Hyprland socket closed, exiting")


async def watch_gamepad(sm: SteamSession, dev: evdev.InputDevice, watched: set) -> None:
    try:
        async for ev in dev.async_read_loop():
            if ev.type == evdev.ecodes.EV_KEY and ev.code == BTN_MODE and ev.value == 1:
                log(f"guide press from {dev.name}")
                sm.on_guide()
    except OSError:
        log(f"gamepad disconnected: {dev.name}")
    finally:
        watched.discard(dev.path)
        try:
            dev.close()
        except OSError:
            pass


async def gamepad_scanner(sm: SteamSession) -> None:
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
                    asyncio.create_task(watch_gamepad(sm, dev, watched))
                else:
                    dev.close()
            except OSError:
                pass
        await asyncio.sleep(3)


async def main() -> None:
    sm = SteamSession()
    asyncio.get_running_loop().add_signal_handler(signal.SIGUSR1, sm.on_guide)
    gamepads = asyncio.create_task(gamepad_scanner(sm))
    await hypr_events(sm)  # returns when Hyprland exits
    gamepads.cancel()


if __name__ == "__main__":
    asyncio.run(main())

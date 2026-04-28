#!/usr/bin/env python3
"""
Lid / monitor / suspend state machine for Hyprland.

Owns:
  - eDP-2 enable/disable (replaces monitors.sh)
  - logind lid-switch handling (held off via handle-lid-switch inhibitor)
  - 30s grace window between lid close and suspend
  - Idle-inhibitor-aware deferral with media auto-pause

Architecture:
  Layer 1 — Effectors:        narrow, idempotent world mutations.
  Layer 2 — on_enter_<STATE>:  composes effectors; the only place side-effects fire.
  Layer 3 — transition table: pure state -> state map; performs no I/O.

Event sources feed a single asyncio.Queue consumed by dispatcher().
"""

import asyncio
import json
import logging
import os
import re
import subprocess
import sys
from collections import deque
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path

from dbus_next import BusType, Variant
from dbus_next.aio import MessageBus
from dbus_next.signature import Variant as SigVariant  # noqa: F401

LOG = logging.getLogger("lid-fsm")

EDP_MONITOR = "eDP-2"
MONITORS_CONF = Path.home() / ".config/hypr/configs/monitors.conf"
HYPRIDLE_LOG = Path.home() / ".config/hypr/logs/hypridle.log"
GRACE_SECONDS = 30
INHIBIT_POLL_SECONDS = 2

# WHO names that always hold logind inhibitors and don't represent real user
# intent to keep the system awake. Anything else with what=idle|sleep mode=block
# is considered a "real" inhibitor.
INHIBIT_BASELINE_WHO = frozenset({
    "ModemManager",
    "NetworkManager",
    "UPower",
    "hypridle",
    "logind-idle-control",
    "hypr-fsm",
})

LOGIND_BUS = "org.freedesktop.login1"
LOGIND_PATH = "/org/freedesktop/login1"
LOGIND_IFACE = "org.freedesktop.login1.Manager"


# -------- Layer 3a: states & events --------

class State(Enum):
    LID_OPEN = "LID_OPEN"
    DOCKED = "DOCKED"
    DEFERRED = "DEFERRED"
    COUNTDOWN = "COUNTDOWN"
    SUSPENDING = "SUSPENDING"


class EventKind(Enum):
    LID_CLOSE = "LidClose"
    LID_OPEN = "LidOpen"
    MONITOR_ADDED = "MonitorAdded"
    MONITOR_REMOVED = "MonitorRemoved"
    INHIBITOR_ON = "InhibitorOn"
    INHIBITOR_OFF = "InhibitorOff"
    TIMER_EXPIRED = "TimerExpired"
    RESUMED = "Resumed"


@dataclass
class Event:
    kind: EventKind
    payload: object = None


@dataclass
class Context:
    lid_closed: bool = False
    ext_mon_count: int = 0
    logind_inhibitor: bool = False
    wayland_inhibitor: bool = False
    timer_task: asyncio.Task | None = None

    @property
    def inhibitor(self) -> bool:
        return self.logind_inhibitor or self.wayland_inhibitor


# -------- Layer 1: effectors --------

class Effectors:
    def __init__(self, bus: MessageBus, manager_iface, queue: asyncio.Queue):
        self.bus = bus
        self.manager = manager_iface
        self.queue = queue
        self._lid_inhibit_fd: int | None = None

    async def take_lid_inhibitor(self) -> None:
        """Hold a block-mode handle-lid-switch inhibitor for our process lifetime.

        While held, logind suppresses its own HandleLidSwitch action, giving us
        exclusive control of the suspend decision.
        """
        fd = await self.manager.call_inhibit(
            "handle-lid-switch",
            "hypr-fsm",
            "30s grace window with monitor/inhibitor cancellation",
            "block",
        )
        self._lid_inhibit_fd = fd
        LOG.info("acquired handle-lid-switch inhibitor (fd=%d)", fd)

    def set_edp(self, on: bool) -> None:
        current_disabled = _edp_is_disabled()
        if on:
            if current_disabled is False:
                return  # already enabled
            # `hyprctl keyword monitor "<mode>"` returns "ok" but doesn't
            # reliably clear a prior `disable` keyword. `hyprctl reload`
            # re-applies monitors.conf and is the only thing that actually
            # re-enables eDP-2. Hard invariant: lid open ⟹ eDP enabled.
            LOG.info("re-enabling %s via hyprctl reload", EDP_MONITOR)
            run(["hyprctl", "reload"], check=False)
        else:
            if current_disabled is True:
                return  # already disabled
            LOG.info("disabling %s", EDP_MONITOR)
            run(["hyprctl", "keyword", "monitor", f"{EDP_MONITOR},disable"], check=False)

    def cancel_timer(self, ctx: Context) -> None:
        if ctx.timer_task and not ctx.timer_task.done():
            ctx.timer_task.cancel()
        ctx.timer_task = None

    def start_timer(self, ctx: Context) -> None:
        self.cancel_timer(ctx)
        ctx.timer_task = asyncio.create_task(self._timer_coro())

    async def _timer_coro(self) -> None:
        try:
            await asyncio.sleep(GRACE_SECONDS)
            await self.queue.put(Event(EventKind.TIMER_EXPIRED))
        except asyncio.CancelledError:
            pass

    def pause_media(self) -> None:
        run(["playerctl", "--all-players", "pause"], check=False)

    async def do_suspend(self) -> None:
        LOG.info("calling logind Suspend()")
        await self.manager.call_suspend(False)


# -------- Layer 2: on_enter handlers --------

async def on_enter(state: State, ctx: Context, fx: Effectors) -> None:
    {
        State.LID_OPEN: _on_enter_lid_open,
        State.DOCKED: _on_enter_docked,
        State.DEFERRED: _on_enter_deferred,
        State.COUNTDOWN: _on_enter_countdown,
        State.SUSPENDING: _on_enter_suspending,
    }[state](ctx, fx)
    if state is State.SUSPENDING:
        await fx.do_suspend()


def _on_enter_lid_open(ctx: Context, fx: Effectors) -> None:
    fx.cancel_timer(ctx)
    fx.set_edp(True)


def _on_enter_docked(ctx: Context, fx: Effectors) -> None:
    fx.cancel_timer(ctx)
    fx.set_edp(False)


def _on_enter_deferred(ctx: Context, fx: Effectors) -> None:
    fx.cancel_timer(ctx)
    fx.set_edp(False)
    fx.pause_media()


def _on_enter_countdown(ctx: Context, fx: Effectors) -> None:
    fx.set_edp(False)
    fx.start_timer(ctx)


def _on_enter_suspending(ctx: Context, fx: Effectors) -> None:
    fx.cancel_timer(ctx)
    # do_suspend is awaited in on_enter() since it's async


# -------- Layer 3b: pure transition function --------

def next_state(state: State, ev: EventKind, ctx: Context) -> State | None:
    """Pure state transition. No I/O, no side-effects."""
    closed_target = (
        State.DOCKED if ctx.ext_mon_count >= 1
        else State.DEFERRED if ctx.inhibitor
        else State.COUNTDOWN
    )

    if state is State.LID_OPEN:
        if ev is EventKind.LID_CLOSE:
            return closed_target
        return None

    if state is State.DOCKED:
        if ev is EventKind.LID_OPEN:
            return State.LID_OPEN
        if ev is EventKind.MONITOR_REMOVED and ctx.ext_mon_count == 0:
            return State.DEFERRED if ctx.inhibitor else State.COUNTDOWN
        return None

    if state is State.DEFERRED:
        if ev is EventKind.LID_OPEN:
            return State.LID_OPEN
        if ev is EventKind.MONITOR_ADDED:
            return State.DOCKED
        if ev is EventKind.INHIBITOR_OFF and not ctx.inhibitor:
            return State.COUNTDOWN
        return None

    if state is State.COUNTDOWN:
        if ev is EventKind.LID_OPEN:
            return State.LID_OPEN
        if ev is EventKind.MONITOR_ADDED:
            return State.DOCKED
        if ev is EventKind.INHIBITOR_ON:
            return State.DEFERRED
        if ev is EventKind.TIMER_EXPIRED:
            return State.SUSPENDING
        return None

    if state is State.SUSPENDING:
        if ev is EventKind.RESUMED:
            return _resumed_target(ctx)
        return None

    return None


def _resumed_target(ctx: Context) -> State:
    """After wake, pick the state that matches the current world snapshot."""
    if not ctx.lid_closed:
        return State.LID_OPEN
    if ctx.ext_mon_count >= 1:
        return State.DOCKED
    if ctx.inhibitor:
        return State.DEFERRED
    return State.COUNTDOWN


# -------- Helpers --------

_RUN_LOG_TAIL: deque[str] = deque(maxlen=10)


def run(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(cmd, check=check, capture_output=True, text=True)
    except subprocess.CalledProcessError as e:
        LOG.warning("command failed: %s (rc=%d): %s", cmd, e.returncode, e.stderr.strip())
        if check:
            raise
        return e


def _read_edp_config() -> str:
    """Parse the eDP-2 monitor line out of monitors.conf, mirroring monitors.sh:43-50."""
    try:
        for line in MONITORS_CONF.read_text().splitlines():
            m = re.match(rf"^\s*monitor\s*=\s*({re.escape(EDP_MONITOR)},.*)$", line)
            if m:
                return m.group(1).strip()
    except OSError:
        pass
    return f"{EDP_MONITOR},preferred,auto,1"


def _edp_is_disabled() -> bool | None:
    """Returns True if eDP is disabled, False if enabled, None if we can't tell."""
    try:
        out = run(["hyprctl", "monitors", "all", "-j"], check=False).stdout
        for m in json.loads(out):
            if m.get("name") == EDP_MONITOR:
                return bool(m.get("disabled", False))
    except Exception as e:
        LOG.warning("_edp_is_disabled failed: %s", e)
    return None


def _hyprctl_ext_monitor_count() -> int:
    try:
        out = run(["hyprctl", "-j", "monitors"]).stdout
        mons = json.loads(out)
        return sum(1 for m in mons if not m["name"].startswith("eDP"))
    except Exception as e:
        LOG.warning("ext_monitor_count failed: %s", e)
        return 0


def _wayland_inhibitor_active() -> bool:
    """Check hypridle's most recent 'Inhibit locks: N' log line."""
    try:
        if not HYPRIDLE_LOG.exists():
            return False
        # Fast tail — read last 8KB to find the latest counter line.
        with HYPRIDLE_LOG.open("rb") as f:
            f.seek(0, 2)
            size = f.tell()
            f.seek(max(0, size - 8192))
            tail = f.read().decode("utf-8", errors="replace")
        latest = None
        for line in tail.splitlines():
            m = re.search(r"Inhibit locks:\s*(\d+)", line)
            if m:
                latest = int(m.group(1))
        return bool(latest and latest > 0)
    except Exception as e:
        LOG.warning("wayland inhibitor check failed: %s", e)
        return False


async def _logind_real_inhibitor_active(manager_iface) -> bool:
    """Call ListInhibitors() and look for non-baseline block-mode idle/sleep inhibitors.

    BlockInhibited (the union property) can't distinguish a baseline inhibit like
    logind-idle-control from a real one (e.g. Chromium playing video), so we have
    to walk the per-inhibitor list. Schema is a(ssssuu): (who, why, what, mode, uid, pid).
    """
    try:
        rows = await manager_iface.call_list_inhibitors()
    except Exception as e:
        LOG.warning("ListInhibitors failed: %s", e)
        return False
    for who, _why, what, mode, _uid, _pid in rows:
        if mode != "block":
            continue
        cats = (what or "").split(":")
        if "idle" not in cats and "sleep" not in cats:
            continue
        if who in INHIBIT_BASELINE_WHO:
            continue
        return True
    return False


# -------- Event sources --------

async def hypr_socket_reader(queue: asyncio.Queue, ctx: Context) -> None:
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if not sig or not runtime:
        LOG.error("HYPRLAND_INSTANCE_SIGNATURE / XDG_RUNTIME_DIR not set")
        return
    sock_path = f"{runtime}/hypr/{sig}/.socket2.sock"

    while True:
        try:
            reader, _writer = await asyncio.open_unix_connection(sock_path)
            LOG.info("connected to Hyprland event socket %s", sock_path)
            while True:
                line_b = await reader.readline()
                if not line_b:
                    break
                line = line_b.decode(errors="replace").strip()
                ev = _parse_hypr_event(line)
                if ev is not None:
                    await queue.put(ev)
        except (FileNotFoundError, ConnectionRefusedError) as e:
            LOG.warning("hypr socket unavailable (%s); retrying in 2s", e)
            await asyncio.sleep(2)
        except Exception as e:
            LOG.exception("hypr socket reader crashed: %s", e)
            await asyncio.sleep(2)


def _parse_hypr_event(line: str) -> Event | None:
    if line.startswith("monitoradded>>") or line.startswith("monitoraddedv2>>"):
        name = line.split(">>", 1)[1].split(",")[0]
        if not name.startswith("eDP"):
            return Event(EventKind.MONITOR_ADDED, payload=name)
    elif line.startswith("monitorremoved>>"):
        name = line.split(">>", 1)[1]
        if not name.startswith("eDP"):
            return Event(EventKind.MONITOR_REMOVED, payload=name)
    return None


async def inhibitor_poller(queue: asyncio.Queue, ctx: Context, manager_iface) -> None:
    """Polls both inhibitor sources every INHIBIT_POLL_SECONDS and emits edges.

    Two independent sources, two payload tags so the dispatcher can update
    ctx.logind_inhibitor and ctx.wayland_inhibitor independently:
      - 'logind': filtered ListInhibitors() — D-Bus inhibitors registered with
        logind, excluding baseline WHO names.
      - 'wayland': hypridle.log 'Inhibit locks: N' tail — Wayland-only idle
        inhibits via zwp_idle_inhibit_manager_v1 (don't go through logind).
    """
    last_logind = ctx.logind_inhibitor
    last_wayland = ctx.wayland_inhibitor
    while True:
        try:
            cur_logind = await _logind_real_inhibitor_active(manager_iface)
        except Exception as e:
            LOG.warning("logind inhibitor poll failed: %s", e)
            cur_logind = last_logind
        cur_wayland = _wayland_inhibitor_active()

        if cur_logind != last_logind:
            await queue.put(Event(
                EventKind.INHIBITOR_ON if cur_logind else EventKind.INHIBITOR_OFF,
                payload="logind",
            ))
            last_logind = cur_logind
        if cur_wayland != last_wayland:
            await queue.put(Event(
                EventKind.INHIBITOR_ON if cur_wayland else EventKind.INHIBITOR_OFF,
                payload="wayland",
            ))
            last_wayland = cur_wayland
        await asyncio.sleep(INHIBIT_POLL_SECONDS)


async def setup_logind_watchers(bus: MessageBus, manager_iface, queue: asyncio.Queue):
    """Subscribe to logind LidClosed PropertiesChanged + PrepareForSleep signals.

    Inhibitor changes are NOT handled here — see inhibitor_poller. The logind
    BlockInhibited property can't distinguish baseline from real inhibitors,
    and doesn't fire when a second idle inhibitor stacks on an existing one.
    """
    introspect = await bus.introspect(LOGIND_BUS, LOGIND_PATH)
    obj = bus.get_proxy_object(LOGIND_BUS, LOGIND_PATH, introspect)
    props = obj.get_interface("org.freedesktop.DBus.Properties")
    mgr = obj.get_interface(LOGIND_IFACE)

    def on_prepare_for_sleep(started: bool):
        if not started:
            asyncio.create_task(queue.put(Event(EventKind.RESUMED)))

    mgr.on_prepare_for_sleep(on_prepare_for_sleep)

    def on_properties_changed(iface: str, changed: dict, _invalidated: list):
        if iface != LOGIND_IFACE:
            return
        if "LidClosed" in changed:
            v = changed["LidClosed"].value
            asyncio.create_task(queue.put(
                Event(EventKind.LID_CLOSE if v else EventKind.LID_OPEN)
            ))

    props.on_properties_changed(on_properties_changed)


# -------- Dispatcher --------

async def dispatcher(queue: asyncio.Queue, ctx: Context, fx: Effectors, initial: State) -> None:
    state = initial
    LOG.info("initial state: %s (ext_mon=%d, inhibitor=%s)",
             state.value, ctx.ext_mon_count, ctx.inhibitor)
    await on_enter(state, ctx, fx)

    while True:
        ev: Event = await queue.get()

        # Update context from event before consulting transition table.
        if ev.kind is EventKind.LID_CLOSE:
            ctx.lid_closed = True
        elif ev.kind is EventKind.LID_OPEN:
            ctx.lid_closed = False
        elif ev.kind is EventKind.MONITOR_ADDED:
            ctx.ext_mon_count += 1
        elif ev.kind is EventKind.MONITOR_REMOVED:
            ctx.ext_mon_count = max(0, ctx.ext_mon_count - 1)
        elif ev.kind is EventKind.INHIBITOR_ON:
            if ev.payload == "logind":
                ctx.logind_inhibitor = True
            elif ev.payload == "wayland":
                ctx.wayland_inhibitor = True
        elif ev.kind is EventKind.INHIBITOR_OFF:
            if ev.payload == "logind":
                ctx.logind_inhibitor = False
            elif ev.payload == "wayland":
                ctx.wayland_inhibitor = False

        new = next_state(state, ev.kind, ctx)
        if new is None or new is state:
            LOG.debug("ignored: %s in %s (ext_mon=%d, inhibitor=%s)",
                      ev.kind.value, state.value, ctx.ext_mon_count, ctx.inhibitor)
            continue

        LOG.info("STATE: %s -> %s (event=%s, ext_mon=%d, inhibitor=%s)",
                 state.value, new.value, ev.kind.value, ctx.ext_mon_count, ctx.inhibitor)
        state = new
        await on_enter(state, ctx, fx)


# -------- Bootstrap --------

async def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        stream=sys.stdout,
    )

    queue: asyncio.Queue = asyncio.Queue()

    bus = await MessageBus(bus_type=BusType.SYSTEM, negotiate_unix_fd=True).connect()
    introspect = await bus.introspect(LOGIND_BUS, LOGIND_PATH)
    obj = bus.get_proxy_object(LOGIND_BUS, LOGIND_PATH, introspect)
    manager = obj.get_interface(LOGIND_IFACE)

    ctx = Context()

    # Take the lid inhibitor first — minimizes the window where logind could
    # honor its own HandleLidSwitch=suspend before we're in control.
    fx = Effectors(bus, manager, queue)
    await fx.take_lid_inhibitor()

    # Snapshot the world.
    ctx.lid_closed = await manager.get_lid_closed()
    ctx.logind_inhibitor = await _logind_real_inhibitor_active(manager)
    ctx.wayland_inhibitor = _wayland_inhibitor_active()
    ctx.ext_mon_count = _hyprctl_ext_monitor_count()

    await setup_logind_watchers(bus, manager, queue)

    initial = _resumed_target(ctx)

    await asyncio.gather(
        dispatcher(queue, ctx, fx, initial),
        hypr_socket_reader(queue, ctx),
        inhibitor_poller(queue, ctx, manager),
    )


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass

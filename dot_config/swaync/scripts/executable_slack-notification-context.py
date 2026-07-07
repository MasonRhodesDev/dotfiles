#!/usr/bin/env python3
"""slack-notification-context

Helpers for recovering context from Slack's own logs when Slack's in-app
notification click handler is dead.

Why: Slack (Electron) drops all JS references to its Notification objects, so
V8 eventually garbage-collects them; Electron then nulls the native delegate
and clicks on stale notifications are silently discarded (see electron
shell/browser/notifications/notification.cc NotificationClicked). The
daemon-side notification stays alive in swaync's control center, so we
reconstruct the click's meaning from Slack's logs instead.

Slack redacts message text in its logs but not teamId/channel/msg ids, and it
logs every NEW_NOTIFICATION within milliseconds of emitting the D-Bus Notify —
so arrival-time correlation identifies the notification reliably.

Usage:
  slack-notification-context.py deeplink <epoch-seconds> [tolerance-seconds]
      Print "slack://channel?team=...&id=...&message=..." for the
      notification that arrived at the given time, or nothing if no
      confident match.
"""

import json
import re
import sys
from datetime import datetime
from pathlib import Path

LOG_DIR = Path.home() / ".config/Slack/logs/default"
# browser.log rotates to browser1.log at ~5MB; check both, newest first.
LOG_FILES = ["browser.log", "browser1.log"]

STAMP = r"^\[(\d{2}/\d{2}/\d{2}), (\d{2}:\d{2}:\d{2}):(\d{3})\] info: Store: "
NEW_RE = re.compile(STAMP + r"NEW_NOTIFICATION \n(\{.*?\n\})", re.M | re.S)


def to_epoch(date_s, time_s, ms):
    ts = datetime.strptime(f"{date_s} {time_s}", "%m/%d/%y %H:%M:%S")
    return ts.timestamp() + int(ms) / 1000.0


def read(name):
    path = LOG_DIR / name
    try:
        return path.read_text(errors="replace") if path.is_file() else ""
    except OSError:
        return ""


def cmd_deeplink(target, tolerance):
    best = None
    for name in LOG_FILES:
        for m in NEW_RE.finditer(read(name)):
            try:
                epoch = to_epoch(m.group(1), m.group(2), m.group(3))
                payload = json.loads(m.group(4))
            except (ValueError, json.JSONDecodeError):
                continue
            delta = abs(epoch - target)
            if delta <= tolerance and (best is None or delta < best[0]):
                best = (delta, payload)
        if best:  # newest log had a match; skip the rotated one
            break
    if not best:
        return
    payload = best[1]
    team = payload.get("teamId") or ""
    channel = payload.get("channel") or ""
    if not (team.startswith("T") and channel and channel[0] in "CDG"):
        return
    uri = f"slack://channel?team={team}&id={channel}"
    # Message-precise navigation: the webapp scrolls to and highlights the
    # message; thread_ts additionally opens the thread pane (same params
    # Slack's own CLICK_NOTIFICATION handler forwards).
    msg = payload.get("msg") or ""
    if re.fullmatch(r"\d+\.\d+", msg):
        uri += f"&message={msg}"
    thread = payload.get("thread_ts") or ""
    if re.fullmatch(r"\d+\.\d+", thread):
        uri += f"&thread_ts={thread}"
    print(uri)


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "deeplink" and len(sys.argv) > 2:
        cmd_deeplink(float(sys.argv[2]),
                     float(sys.argv[3]) if len(sys.argv) > 3 else 6.0)
    else:
        sys.exit(__doc__ and 2)


if __name__ == "__main__":
    main()

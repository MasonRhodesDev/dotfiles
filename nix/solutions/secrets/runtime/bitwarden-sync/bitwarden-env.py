#!/usr/bin/env python3
import json
import os
import re
import subprocess
import sys
import time

CONF_DIR = os.path.expanduser("~/.config/bitwarden")
MACHINE_ENV = os.path.join(CONF_DIR, "machine.env")
PROJECT = os.path.join(CONF_DIR, "project.json")
LIST = "@list@"

DENY = {"PATH", "HOME", "USER", "SHELL", "BASH_ENV", "ENV", "IFS", "PS1", "PS2",
        "PROMPT_COMMAND", "LD_PRELOAD", "LD_LIBRARY_PATH", "PWD", "OLDPWD"}
VALID_KEY = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


class Unavailable(Exception):
    pass


def log(msg):
    print(msg, file=sys.stderr, flush=True)


def fetch():
    try:
        with open(PROJECT) as f:
            project = json.load(f).get("envProject", "")
    except (OSError, ValueError):
        project = ""
    if not project:
        raise Unavailable("no Bitwarden env project for this machine (private.bitwarden.envProject in its entry)")
    done = subprocess.run([LIST, project], capture_output=True, text=True)
    if done.returncode != 0:
        lines = done.stderr.strip().splitlines()
        raise Unavailable(lines[-1] if lines else f"listing the Bitwarden project {project} failed")
    try:
        items = json.loads(done.stdout or "[]")
    except ValueError:
        raise Unavailable("Bitwarden answered with something other than a list of secrets")
    secrets, skipped = {}, []
    for item in items:
        k, v = item.get("key", ""), item.get("value", "")
        if not VALID_KEY.match(k) or k in DENY or k in secrets:
            skipped.append(k)
            continue
        secrets[k] = v
    return secrets, skipped


def sync():
    interval = int(os.environ.get("BITWARDEN_SYNC_INTERVAL", "60"))
    said, sent = None, None
    while True:
        try:
            secrets, skipped = fetch()
            status = f"syncing {len(secrets)} keys" + (f", skipping {len(skipped)} unusable names" if skipped else "")
            if secrets != sent:
                print(json.dumps(secrets, sort_keys=True), flush=True)
                sent = secrets
        except Unavailable as e:
            status = f"{e}; keeping what was sent before"
        if status != said:
            log(status)
            said = status
        time.sleep(interval)


def run(argv):
    if not argv:
        log("usage: bitwarden-exec COMMAND [ARG...]")
        return 2
    try:
        secrets, _ = fetch()
    except Unavailable as e:
        log(f"bitwarden-exec: {e}")
        return 3
    try:
        os.execvpe(argv[0], argv, {**os.environ, **secrets})
    except OSError as e:
        log(f"bitwarden-exec: {argv[0]}: {e.strerror}")
        return 127


if __name__ == "__main__":
    if sys.argv[1:2] == ["exec"]:
        sys.exit(run(sys.argv[2:]))
    sync()

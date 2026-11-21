#!/usr/bin/env python3
import json
import os
import re
import subprocess
import sys
import time

CONF_DIR = os.path.expanduser("~/.config/infisical")
MACHINE_ENV = os.path.join(CONF_DIR, "machine.env")
PROJECT = os.path.join(CONF_DIR, "project.json")
LOGIN = "@login@"

DENY = {"PATH", "HOME", "USER", "SHELL", "BASH_ENV", "ENV", "IFS", "PS1", "PS2",
        "PROMPT_COMMAND", "LD_PRELOAD", "LD_LIBRARY_PATH", "PWD", "OLDPWD"}
VALID_KEY = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def log(msg):
    print(msg, file=sys.stderr, flush=True)


def unconfigured():
    if not os.path.exists(PROJECT):
        return "no Infisical project for this machine (private.infisical in its entry)"
    if not os.path.exists(MACHINE_ENV):
        return f"not logged in to Infisical: {MACHINE_ENV} is missing"
    return None


def load_project():
    with open(PROJECT) as f:
        return json.load(f)


def login():
    return subprocess.run([LOGIN], check=True, capture_output=True, text=True).stdout.strip()


def fetch(project, token):
    out = subprocess.run(
        ["infisical", "export", "--format=json", "--silent",
         "--projectId", project["projectId"],
         "--env", project["environment"],
         "--path", project["path"]],
        check=True, capture_output=True, text=True,
        env={**os.environ, "INFISICAL_TOKEN": token}).stdout
    secrets = {}
    for item in json.loads(out or "[]"):
        k = item.get("key", item.get("secretKey"))
        v = item.get("value", item.get("secretValue", ""))
        if not k or not VALID_KEY.match(k) or k in DENY:
            log(f"skipping unsafe key: {k!r}")
            continue
        secrets[k] = v
    return secrets


def emit(secrets, sent):
    if secrets == sent:
        return False
    print(json.dumps(secrets, sort_keys=True), flush=True)
    return True


def main():
    interval = int(os.environ.get("INFISICAL_SYNC_INTERVAL", "10"))
    token, sent = None, None
    while True:
        reason = unconfigured()
        if reason:
            log(f"{reason}; not syncing")
            return
        try:
            project = load_project()
            if token is None:
                token = login()
                log("logged in")
            try:
                secrets = fetch(project, token)
            except subprocess.CalledProcessError:
                token = login()
                secrets = fetch(project, token)
            if emit(secrets, sent):
                sent = secrets
                log(f"env project sent ({len(secrets)} keys)")
        except subprocess.CalledProcessError as e:
            token = None
            msgs = [l.strip() for l in (e.stderr or "").splitlines() if "Message:" in l]
            log(f"sync failed, keeping what was sent before: {msgs[0] if msgs else (e.stderr or '').strip()[-300:]}")
        except Exception as e:
            token = None
            log(f"sync failed, keeping what was sent before: {e}")
        time.sleep(interval)


if __name__ == "__main__":
    main()

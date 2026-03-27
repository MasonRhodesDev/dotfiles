#!/usr/bin/env python3
"""
Chezmoi package checker.
Uses Claude haiku to audit manifest packages AND detect untracked drift.

Usage:
    chezmoi-package-check.py
"""

import json
import os
import re
import socket
import subprocess
import sys
from pathlib import Path

CHEZMOI_DIR = Path.home() / ".local" / "share" / "chezmoi"
REGISTRY = CHEZMOI_DIR / "software_installers" / "packages.toml"
CLAUDE_BIN = Path.home() / ".local" / "bin" / "claude"


def detect_profile():
    hostname = socket.gethostname()
    return "work" if hostname == "mason-work" else "personal"


def find_claude():
    if CLAUDE_BIN.is_file() and os.access(CLAUDE_BIN, os.X_OK):
        return str(CLAUDE_BIN)
    return None


def read_manifest():
    return REGISTRY.read_text()


def collect_drift_data():
    """Pre-compute all data for drift detection so haiku doesn't need to explore."""
    dot_config = CHEZMOI_DIR / "dot_config"
    skip_dirs = {"environment.d", "systemd", "udev", "xdg-desktop-portal", "autostart", "git", "ags"}

    # 1. Config directories
    config_dirs = []
    if dot_config.is_dir():
        for d in sorted(dot_config.iterdir()):
            if d.is_dir():
                name = d.name.removeprefix("private_")
                if name not in skip_dirs and not re.match(r"^gtk-\d", name):
                    config_dirs.append(name)

    # 2. Hyprland exec apps
    hypr_dir = dot_config / "hypr"
    skip_cmds = {"sleep", "sed", "killall", "systemctl", "dbus-update-activation-environment",
                 "gsettings", "pkill", "pgrep", "sh", "bash", "env",
                 # sub-binaries from larger packages — not standalone installs
                 "gnome-keyring-daemon", "wpctl", "wl-copy", "wl-paste"}
    hypr_exec = set()
    hypr_binds = set()

    if hypr_dir.is_dir():
        for f in hypr_dir.rglob("*"):
            if not f.is_file():
                continue
            try:
                content = f.read_text()
            except (OSError, UnicodeDecodeError):
                continue

            for m in re.finditer(r"(?:exec-once|exec)\s*=\s*(.*)", content):
                cmd = m.group(1).strip().lstrip("[").split()[0].split("/")[-1]
                if cmd and cmd not in skip_cmds:
                    hypr_exec.add(cmd)

            for m in re.finditer(r"bind.*exec,\s*(\S+)", content):
                cmd = m.group(1).split()[0].split("/")[-1]
                if cmd and not cmd.startswith("$") and cmd != "exec" and not re.match(r".*\.(sh|js|py)$", cmd):
                    hypr_binds.add(cmd)

    # 3. Script names
    scripts_dir = CHEZMOI_DIR / "scripts"
    script_names = []
    if scripts_dir.is_dir():
        for f in sorted(scripts_dir.iterdir()):
            script_names.append(f.name.removeprefix("executable_"))

    # 4. Flatpak apps
    flatpak_apps = ""
    try:
        flatpak_apps = subprocess.run(
            ["flatpak", "list", "--app", "--columns=application"],
            capture_output=True, text=True, timeout=10
        ).stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    # 5. Cargo tools
    cargo_tools = ""
    try:
        result = subprocess.run(
            ["cargo", "install", "--list"],
            capture_output=True, text=True, timeout=10
        )
        cargo_tools = "\n".join(
            line.split()[0] for line in result.stdout.splitlines()
            if line and not line.startswith(" ")
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    # 6. Manifest entry keys (top-level TOML table names)
    manifest_text = read_manifest()
    manifest_pkgs = sorted(set(re.findall(r'^\[(\w+)\]', manifest_text, re.MULTILINE)))

    return {
        "config_dirs": "\n".join(config_dirs),
        "hypr_exec": "\n".join(sorted(hypr_exec)),
        "hypr_binds": "\n".join(sorted(hypr_binds)),
        "script_names": "\n".join(script_names),
        "flatpak_apps": flatpak_apps,
        "cargo_tools": cargo_tools,
        "manifest_pkgs": "\n".join(manifest_pkgs),
        "packages_toml": manifest_text,
    }


def parse_stream_line(data):
    """Extract progress info from a stream-json event."""
    if data.get("type") == "assistant":
        for block in data.get("message", {}).get("content", []):
            if block.get("type") == "tool_use":
                cmd = block.get("input", {}).get("command") or block.get("name", "working...")
                return f"  > {cmd}"
            elif block.get("type") == "text":
                return f"\n{block['text']}"
    return None


def run_claude_check(claude_bin, system_prompt, user_prompt):
    """Run claude in print mode with stream-json, showing progress. Returns final result text."""
    cmd = [
        claude_bin, "--model", "haiku", "-p", "--verbose",
        "--output-format", "stream-json", "--include-partial-messages",
        "--dangerously-skip-permissions", "--allow-dangerously-skip-permissions",
        "--system-prompt", system_prompt,
        user_prompt,
    ]

    result_text = ""
    try:
        proc = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True
        )
        for line in proc.stdout:
            line = line.strip()
            if not line:
                continue
            try:
                data = json.loads(line)
            except json.JSONDecodeError:
                continue

            # Show progress
            progress = parse_stream_line(data)
            if progress:
                print(progress, flush=True)

            # Capture final result
            if data.get("type") == "result":
                result_text = data.get("result", "")

        proc.wait()
    except (OSError, KeyboardInterrupt):
        pass

    return result_text


def run_claude_interactive(claude_bin, system_prompt, seed_message=""):
    """Replace this process with an interactive Claude session."""
    args = [claude_bin, "--model", "haiku", "--system-prompt", system_prompt]
    if seed_message:
        args.append(seed_message)
    os.execvp(claude_bin, args)


def prompt_user(question, timeout=120):
    """Prompt user via /dev/tty with timeout. Returns response or empty string."""
    try:
        tty = open("/dev/tty", "r")
        print(f"\n{question} [y/N] ", end="", flush=True)
        import select
        ready, _, _ = select.select([tty], [], [], timeout)
        if ready:
            return tty.readline().strip()
        print("(timed out)")
        return ""
    except (OSError, EOFError):
        return ""


def run_audit(claude_bin, profile):
    """Post-apply: check manifest packages are installed AND find untracked drift."""
    data = collect_drift_data()
    packages_toml = data["packages_toml"]

    system_prompt = f"""You are a system package auditor with TWO jobs. Be concise and fast — minimize Bash calls.

PROFILE: {profile}

packages.toml:
---
{packages_toml}
---

CHEZMOI CONFIG DIRS (implies app installed):
{data['config_dirs']}

HYPRLAND EXEC APPS:
{data['hypr_exec']}

HYPRLAND KEYBIND APPS:
{data['hypr_binds']}

INSTALLED FLATPAKS:
{data['flatpak_apps']}

INSTALLED CARGO TOOLS:
{data['cargo_tools']}

MANIFEST ENTRY KEYS:
{data['manifest_pkgs']}

--- JOB 1: Missing manifest packages ---
1. Detect distro in ONE call: `command -v dnf && echo fedora || echo arch`
2. Check ONLY entries where profile = "common" or profile = "{profile}". Skip optional = true entries.
3. For each entry, use its `verify` field to check if installed. Batch into ONE Bash call:
   `for cmd in "cmd1" "cmd2"; do eval "$cmd" &>/dev/null || echo "MISSING: $cmd"; done`
4. If no `verify` field, infer the binary name from the entry key and run `command -v <key>`.
5. Report ONLY entries that are genuinely not installed.

--- JOB 2: Untracked drift ---
6. Cross-reference config dirs + hypr apps + flatpaks + cargo tools against manifest entry keys.
7. Config dir name maps to entry key (btop→btop, swaync→part of hyprland, zed→zed, etc.).
8. SKIP: sub-binaries bundled with tracked entries (e.g. swaync-client is part of hyprland entry).
9. Flatpak: flag only if app ID doesn't appear in any verify field in the manifest.
10. Cargo: flag only if crate name doesn't match any manifest key or appear in any description.
11. Use ONE Bash call to confirm a flagged item is actually installed before reporting it.

Output format:
- Section 1: "Missing Manifest Packages" — one line per entry key
- Section 2: "Untracked Dependencies" — one line each with brief note
- If both empty: output exactly 'All packages up to date. No drift detected.'"""

    print("\n=== Full package audit + drift check ===")
    result = run_claude_check(claude_bin, system_prompt,
                              f"Run full audit for the {profile} profile: check manifest packages AND find untracked drift.")

    if re.search(r"all.*up to date.*no.*drift|no.*missing.*no.*drift", result, re.IGNORECASE):
        return

    response = prompt_user("Would you like Claude to help fix these issues?")
    if response.lower().startswith("y"):
        interactive_prompt = f"""You are a packages.toml manifest editor. Your job is to update {REGISTRY} based on audit findings.

packages.toml:
---
{packages_toml}
---

Rules:
- Your PRIMARY action is editing packages.toml using the Edit tool.
- For untracked apps: add them to the appropriate [common/work/personal.*] section following the existing TOML format. Include both fedora and arch sub-tables where applicable.
- For missing packages: they are already in the manifest — do NOT re-add them. Just confirm they're present and let the user know they need to be installed.
- Ask the user item-by-item what they want to do. Do not batch-edit without confirmation.
- Do not explore the filesystem, run installs, or do anything outside editing packages.toml unless the user explicitly asks."""

        seed = (
            f"Audit report for the {profile} profile:\n\n{result}\n\n"
            "Briefly list the untracked items and missing packages, then ask me which ones to add/fix."
        )
        run_claude_interactive(claude_bin, interactive_prompt, seed)


def main():
    if not sys.stdin.isatty():
        sys.exit(0)

    claude_bin = find_claude()
    if not claude_bin:
        print("[package-check] Claude CLI not found, skipping")
        sys.exit(0)

    if not REGISTRY.is_file():
        sys.exit(0)

    profile = detect_profile()
    run_audit(claude_bin, profile)


if __name__ == "__main__":
    main()

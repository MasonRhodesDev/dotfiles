"""Print the parity manifest of a deployed home tree.

usage: python3 -I manifest.py TREE [SCRIPTS_JSON]

Without SCRIPTS_JSON: one line per target, `<type> <mode> <sha256|target|-> <path>`.
With SCRIPTS_JSON (`chezmoi managed --include scripts --path-style all --format json`):
one line per script, `<trigger> <sha256|empty> <name>`.

Any /home/<account> in content or a symlink target is hashed as /home/USER, so a
tree rendered for any account compares equal. /home/linuxbrew is a system path.
"""

import hashlib
import json
import os
import re
import stat
import sys

HOME = re.compile(rb"/home/(?!linuxbrew/)[a-z_][a-z0-9_-]*")
SCRIPT = re.compile(r"run_(once_|onchange_)?(before_|after_)?")


def normalize(data):
    return HOME.sub(b"/home/USER", data)


def sha256(path):
    with open(path, "rb") as f:
        return hashlib.sha256(normalize(f.read())).hexdigest()


def entry(tree, rel):
    path = os.path.join(tree, rel)
    st = os.lstat(path)
    if stat.S_ISLNK(st.st_mode):
        return rel, f"l - {normalize(os.readlink(path).encode()).decode()} {rel}"
    mode = f"{stat.S_IMODE(st.st_mode):04o}"
    if stat.S_ISDIR(st.st_mode):
        return rel, f"d {mode} - {rel}"
    return rel, f"f {mode} {sha256(path)} {rel}"


def walk(tree):
    for root, dirs, files in os.walk(tree):
        for name in dirs + files:
            yield os.path.relpath(os.path.join(root, name), tree)


def trigger(source_relative):
    m = SCRIPT.match(os.path.basename(source_relative))
    when = (m.group(1) or "always_").rstrip("_")
    order = (m.group(2) or "during_").rstrip("_")
    return f"{when}-{order}"


def scripts(tree, managed):
    for name, paths in managed.items():
        source = paths["sourceRelative"]
        if not SCRIPT.match(os.path.basename(source)):
            continue
        path = os.path.join(tree, name)
        digest = sha256(path) if os.path.exists(path) else "empty"
        yield name, f"{trigger(source)} {digest} {name}"


def main():
    tree = sys.argv[1]
    if len(sys.argv) > 2:
        with open(sys.argv[2]) as f:
            lines = scripts(tree, json.load(f))
    else:
        lines = (entry(tree, rel) for rel in walk(tree))
    for _, line in sorted(lines):
        print(line)


main()

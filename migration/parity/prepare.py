"""Prepare a chezmoi export and its profiles for a render that reads nothing from the host.

usage:
  python3 -I prepare.py fill PROFILE DATA_DIR    print PROFILE with each @key@ replaced by
                                                 DATA_DIR/<profile name>.toml's string `key`
  python3 -I prepare.py export SRC PROFILE...    answer stat probes from .parity.host_paths,
                                                 then refuse any template action that could read
                                                 the rendering host, for every filled PROFILE

The guard is an allowlist. An action may use only the keywords and functions in
ALLOWED, variables, string and number literals, and data fields. A `.chezmoi`
field must name a key the profile pins under [data.chezmoi], and an osRelease
field one it pins under [data.chezmoi.osRelease]. The whole data map, a bare
`.` or `$`, may only be dig's map, and a dig action may hold no variable.
Anything else fails, as does the string "chezmoi" (which `dig` and `index`
could follow into unpinned keys), an `include` of a path outside the source, a
`chezmoi:template:` directive, any .chezmoiexternal file, and an action the
tokenizer cannot read.
"""

import os
import re
import sys
import tomllib

ALLOWED = {
    "if", "else", "end", "range", "with",
    "and", "or", "not", "eq", "ne",
    "dig", "list", "quote", "include", "sha256sum", "has",
    "true", "false", "nil",
}

ACTION = re.compile(r"\{\{-?\s*(.*?)\s*-?\}\}", re.S)
STAT = re.compile(r'\bstat(\s+"(?:[^"\\]|\\.)*")')
TOKEN = re.compile(r"""
    (?P<space>\s+)
  | (?P<string>"(?:[^"\\]|\\.)*"|`[^`]*`)
  | (?P<field>(?:\$[A-Za-z_]\w*|\$)?(?:\.[A-Za-z_]\w*)+)
  | (?P<var>\$[A-Za-z_]\w*|\$)
  | (?P<dot>\.)
  | (?P<ident>[A-Za-z_]\w*)
  | (?P<number>-?\d+)
  | (?P<punct>:=|=|\||\(|\)|,)
""", re.X)
PLACEHOLDER = re.compile(r"@([a-z_]+)@")


def fill(profile, data_dir):
    name = os.path.basename(profile).removesuffix(".toml")
    with open(os.path.join(data_dir, f"{name}.toml"), "rb") as f:
        values = tomllib.load(f)
    with open(profile) as f:
        text = f.read()
    wanted = set(PLACEHOLDER.findall(text))
    problems = [f"{name}: no value for @{k}@" for k in sorted(wanted - set(values))]
    problems += [f"{name}: {k} is not a placeholder in the profile" for k in sorted(set(values) - wanted)]
    problems += [f"{name}: {k} must be a string" for k, v in sorted(values.items()) if not isinstance(v, str)]
    if problems:
        sys.exit("\n".join(problems))
    filled = PLACEHOLDER.sub(lambda m: values[m.group(1)].replace("\\", "\\\\").replace('"', '\\"'), text)
    tomllib.loads(filled)
    return filled


def pinned(profile):
    with open(profile, "rb") as f:
        chezmoi = tomllib.load(f)["data"]["chezmoi"]
    return set(chezmoi) - {"osRelease"}, set(chezmoi.get("osRelease", {}))


def tokens(action):
    pos = 0
    while pos < len(action):
        m = TOKEN.match(action, pos)
        if not m:
            raise ValueError(f"cannot read from {action[pos:pos + 20]!r}")
        pos = m.end()
        if m.lastgroup != "space":
            yield m.lastgroup, m.group()


def dig_maps(toks):
    """Indexes of a bare `.` or `$` passed as dig's last argument, its map."""
    found = set()
    for i, tok in enumerate(toks):
        if tok != ("ident", "dig"):
            continue
        depth, last = 0, None
        for j in range(i + 1, len(toks)):
            text = toks[j][1]
            if text == ")" and depth == 0 or text == "|" and depth == 0:
                break
            if depth == 0 and text != ")":
                last = j
            depth += (text == "(") - (text == ")")
        if last is not None and toks[last] in (("dot", "."), ("var", "$")):
            found.add(last)
    return found


def refusals(action, keys, os_keys):
    if action.startswith("/*"):
        return []
    try:
        toks = list(tokens(action))
    except ValueError as e:
        return [str(e)]
    found = []
    strings = [t[1:-1] for kind, t in toks if kind == "string"]
    for kind, text in toks:
        if kind == "ident" and text not in ALLOWED:
            found.append(f"{text} is not on the allowlist")
        elif kind == "field":
            fields = text.split(".")[1:]
            if "chezmoi" in fields:
                rest = fields[fields.index("chezmoi") + 1:]
                if not rest or rest[0] not in keys | {"osRelease"}:
                    found.append(f"{text} is not pinned by the profile")
                elif rest[0] == "osRelease" and (len(rest) < 2 or rest[1] not in os_keys):
                    found.append(f"{text} is not pinned by the profile")
    maps = dig_maps(toks)
    for i, (kind, text) in enumerate(toks):
        if (kind == "dot" or text == "$") and i not in maps:
            found.append(f"{text} hands the whole data map, .chezmoi included, to something other than dig")
    if maps and any(kind == "var" and text != "$" for kind, text in toks):
        found.append("a variable in a dig action can name an unpinned key")
    if "chezmoi" in strings:
        found.append('the string "chezmoi" can reach unpinned keys')
    # Go unescapes a string before using it, so an escape can spell what the
    # checks above and below look for.
    found += [f"the string {s!r} has an escape, which can hide a path or a key" for s in strings if "\\" in s]
    for i, t in enumerate(toks):
        if t == ("ident", "include"):
            if i + 1 >= len(toks) or toks[i + 1][0] != "string":
                found.append("include of something other than a string literal can read outside the source")
    if any(t == ("ident", "include") for t in toks):
        found += [f"include of {s!r} reads outside the source" for s in strings
                  if s.startswith(("/", "~")) or ".." in s.split("/")]
    return found


def templates(src):
    for root, dirs, files in os.walk(src):
        dirs.sort()
        rel = os.path.relpath(root, src)
        for name in sorted(files):
            path = os.path.join(root, name)
            if name.startswith(".chezmoiexternal") or "/.chezmoiexternals" in "/" + rel:
                yield path, None
            elif name.endswith(".tmpl") or name in (".chezmoiignore", ".chezmoiremove") \
                    or rel.split(os.sep)[0] == ".chezmoitemplates":
                yield path, True


def export(src, profiles):
    pins = [pinned(p) for p in profiles]
    found = []
    seen = list(templates(src))
    if not seen:
        return [f"{src}: no templates, so this is not a chezmoi source"]
    for path, is_template in seen:
        rel = os.path.relpath(path, src)
        if is_template is None:
            found.append(f"{rel}: externals are fetched from the network")
            continue
        with open(path) as f:
            text = f.read()
        if "chezmoi:template:" in text:
            found.append(f"{rel}: sets template options, such as its delimiters, that this guard does not follow")
            continue
        text = ACTION.sub(lambda m: m.group(0).replace(m.group(1), STAT.sub(r"has\1 .parity.host_paths", m.group(1))), text)
        with open(path, "w") as f:
            f.write(text)
        for m in ACTION.finditer(text):
            for keys, os_keys in pins:
                found += [f"{rel}: {{{{ {m.group(1)} }}}}: {why}" for why in refusals(m.group(1), keys, os_keys)]
    return sorted(set(found))


def main():
    if len(sys.argv) == 4 and sys.argv[1] == "fill":
        sys.stdout.write(fill(sys.argv[2], sys.argv[3]))
    elif len(sys.argv) >= 4 and sys.argv[1] == "export":
        found = export(sys.argv[2], sys.argv[3:])
        if found:
            sys.exit("template actions that could read the rendering host:\n" + "\n".join(found))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()

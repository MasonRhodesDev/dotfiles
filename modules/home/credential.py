import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile

KEY = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
LIMIT = 30


def say(line):
    print(f"dotfiles-credential: {line}", file=sys.stderr, flush=True)


def last_line(text, fallback):
    lines = [line.strip() for line in (text or "").splitlines() if line.strip()]
    return lines[-1] if lines else fallback


def strip_newline(value):
    return value[:-1] if value.endswith("\n") else value


def call(argv, deadline=LIMIT, stdin=None, env=None):
    child = subprocess.Popen(argv, stdin=subprocess.PIPE if stdin is not None else subprocess.DEVNULL,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                             start_new_session=True, env=env)
    try:
        out, err = child.communicate(stdin, timeout=deadline)
    except subprocess.TimeoutExpired:
        os.killpg(child.pid, signal.SIGKILL)
        child.communicate()
        return None, None, f"did not answer within {deadline:g} s"
    return child.returncode, out, err


class Provider:
    label = "provider"

    def __init__(self, runtime):
        self.get_program = runtime["get"]
        self.has_program = runtime["has"]

    def fetch(self, name):
        try:
            code, out, err = call([self.get_program, name])
        except OSError as e:
            return None, f"cannot run: {e.strerror}"
        if code is None:
            return None, err
        if code == 0 and out:
            return out, None
        return None, last_line(err, f"exited {code}")

    def presence(self, names, deadline):
        if not names:
            return {}
        try:
            code, out, err = call([self.has_program, *names], deadline or LIMIT)
        except OSError as e:
            return {name: ("provider unreachable", f"cannot run: {e.strerror}") for name in names}
        if code is None:
            return {name: ("provider unreachable", f"the provider did not answer within {deadline or LIMIT:g} s") for name in names}
        if code == 0:
            held = set(out.split("\n"))
            return {name: ("present", None) if name in held else ("missing", "the provider does not hold it") for name in names}
        status = "provider not configured" if code == 4 else "provider unreachable"
        return {name: (status, last_line(err, f"the provider check exited {code}")) for name in names}


class Derive:
    label = "derive"

    def __init__(self, command):
        self.command = command

    def fetch(self, name):
        try:
            code, out, err = call(["/bin/sh", "-c", self.command])
        except OSError as e:
            return None, f"cannot run: {e.strerror}"
        if code is None:
            return None, f"{self.command} {err}"
        value = strip_newline(out or "")
        if code == 0 and value:
            return value, None
        return None, f"{self.command} gave nothing (exit {code})"


STORES = {}


def store(kind):
    def register(cls):
        STORES[kind] = cls
        cls.kind = kind
        return cls
    return register


class LocalStore:
    label = "local store"

    def __init__(self, config):
        pass


@store("secret-service")
class SecretService(LocalStore):
    def __init__(self, config):
        bus = f"/run/user/{os.getuid()}/bus"
        if "DBUS_SESSION_BUS_ADDRESS" not in os.environ and os.path.exists(bus):
            os.environ["DBUS_SESSION_BUS_ADDRESS"] = f"unix:path={bus}"

    def where(self, name):
        return f"keyring item service=dotfiles account={name}"

    def fetch(self, name):
        try:
            code, out, err = call(["secret-tool", "lookup", "service", "dotfiles", "account", name], 10)
        except OSError:
            return None, "secret-tool is not installed"
        if code is None:
            return None, f"the keyring {err}"
        if code == 0 and out:
            return out, None
        if not (err or "").strip():
            return None, f"no {self.where(name)}"
        return None, f"the keyring cannot be read: {last_line(err, 'secret-tool failed')}"

    def keep(self, name, value):
        code, _, err = call(["secret-tool", "store", "--label", f"dotfiles {name}", "service", "dotfiles", "account", name], LIMIT, value)
        return code == 0, last_line(err, "secret-tool store failed")


@store("keychain")
class Keychain(LocalStore):
    def where(self, name):
        return f"login Keychain item with service dotfiles and account {name}"

    def fetch(self, name):
        try:
            code, out, err = call(["security", "find-generic-password", "-s", "dotfiles", "-a", name, "-w"], 10)
        except OSError:
            return None, "the security tool is missing"
        if code is None:
            return None, f"the Keychain {err}"
        value = strip_newline(out or "")
        if code == 0 and value:
            return value, None
        if code == 44:
            return None, f"no {self.where(name)}"
        return None, f"the login Keychain cannot be read (locked, or no GUI session): {last_line(err, f'exit {code}')}"

    def keep(self, name, value):
        if any(c in value for c in '"\\\n'):
            return False, "a value with a double quote, a backslash or a newline cannot go to the Keychain this way"
        code, _, err = call(["security", "-i"], LIMIT, f'add-generic-password -U -s dotfiles -a "{name}" -w "{value}"\n')
        return code == 0, last_line(err, "security add-generic-password failed")


@store("file")
class Files(LocalStore):
    def __init__(self, config):
        self.root = os.path.join(os.path.expanduser("~"), ".local", "state", "dotfiles", "credentials")

    def where(self, name):
        return f"~/.local/state/dotfiles/credentials/{name}"

    def fetch(self, name):
        path = os.path.join(self.root, name)
        try:
            st = os.lstat(path)
        except FileNotFoundError:
            return None, f"no file {self.where(name)}"
        except OSError as e:
            return None, f"{self.where(name)} cannot be read: {e.strerror}"
        if not os.path.isfile(path) or os.path.islink(path):
            return None, f"{self.where(name)} is not a regular file, so it is not used"
        if st.st_mode & 0o077:
            return None, f"{self.where(name)} is readable by others, so it is not used; chmod 600 it"
        try:
            with open(path) as f:
                value = strip_newline(f.read())
        except OSError as e:
            return None, f"{self.where(name)} cannot be read: {e.strerror}"
        if not value:
            return None, f"{self.where(name)} is empty"
        return value, None

    def keep(self, name, value):
        parts = name.split("/")
        for depth in range(len(parts)):
            directory = os.path.join(self.root, *parts[:depth])
            os.makedirs(directory, mode=0o700, exist_ok=True)
            os.chmod(directory, 0o700)
        path = os.path.join(self.root, name)
        fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".incoming.")
        with os.fdopen(fd, "w") as f:
            f.write(value)
        os.replace(tmp, path)
        return True, None


def tiers(config, credential):
    found = []
    if config.get("store"):
        found.append(STORES[config["store"]](config))
    found.append(Provider(config["runtime"]))
    if credential.get("derive"):
        found.append(Derive(credential["derive"]))
    return found


def declared(config, name):
    credential = config["credentials"].get(name)
    if credential is None:
        say(f"'{name}' is not a declared credential")
        sys.exit(2)
    return credential


def manual(name, credential):
    login = credential["deliver"].get("login")
    if login:
        return f"run: {login}"
    return f"run: dotfiles-credential set {name}"


def resolve(config, name):
    credential = declared(config, name)
    if credential["deliver"].get("login"):
        return None, [f"{name} is a login its consumer keeps; {manual(name, credential)}"]
    said = []
    for tier in tiers(config, credential):
        value, why = tier.fetch(name)
        if value:
            return value, None
        said.append(f"{tier.label}: {why}")
    return None, said


def get(config, args):
    if len(args) != 1:
        say("get takes one credential name")
        return 2
    name = args[0]
    value, said = resolve(config, name)
    if value is None:
        print(f"{name} is unavailable ({'; '.join(said)}). To add it here, {manual(name, config['credentials'][name])}", file=sys.stderr)
        return 3
    sys.stdout.write(value)
    return 0


def keep(config, args):
    if len(args) != 1:
        say("set takes one credential name and reads the value on stdin")
        return 2
    name = args[0]
    credential = declared(config, name)
    if credential["deliver"].get("login"):
        say(f"{name} is a login its consumer keeps; {manual(name, credential)}")
        return 2
    if not config.get("store"):
        say("this machine has no local store")
        return 3
    value = strip_newline(sys.stdin.read())
    if not value:
        say(f"no value on stdin, so {name} is left as it was")
        return 2
    local = STORES[config["store"]](config)
    stored, why = local.keep(name, value)
    if not stored:
        say(f"{name} was not stored: {why}")
        return 3
    print(f"dotfiles-credential: stored {name} in {local.where(name)}", file=sys.stderr)
    return 0


def runtime_dir():
    for candidate in (os.environ.get("XDG_RUNTIME_DIR"), os.environ.get("TMPDIR"), "/tmp"):
        if candidate and os.path.isdir(candidate):
            return candidate
    return "/tmp"


def write_private(root, relative, value):
    parts = relative.split("/")
    for depth in range(len(parts)):
        directory = os.path.join(root, *parts[:depth])
        os.makedirs(directory, mode=0o700, exist_ok=True)
        os.chmod(directory, 0o700)
    fd = os.open(os.path.join(root, relative), os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(value)


def parse_pairs(args):
    wanted, command = {"env": [], "file": [], "stdin": []}, None
    while args:
        word = args.pop(0)
        if word == "--":
            command = args
            break
        if word not in ("--env", "--file", "--stdin") or not args:
            return None, None
        kind, spec = word[2:], args.pop(0)
        if kind == "stdin":
            wanted[kind].append((spec, None))
            continue
        name, _, variable = spec.partition("=")
        if not KEY.match(variable):
            return None, None
        wanted[kind].append((name, variable))
    return wanted, command


def run(config, args):
    wanted, command = parse_pairs(args)
    if wanted is None or not command or len(wanted["stdin"]) > 1:
        say("run takes --env NAME=VAR, --file NAME=VAR and one --stdin NAME, then -- and the command")
        return 2
    values, missing = {}, []
    for name, _ in wanted["env"] + wanted["file"] + wanted["stdin"]:
        declared(config, name)
        if name not in values:
            value, _ = resolve(config, name)
            if value:
                values[name] = value
            else:
                missing.append(name)
    env = dict(os.environ)
    env.pop("DOTFILES_CREDENTIALS_MISSING", None)
    if missing:
        env["DOTFILES_CREDENTIALS_MISSING"] = " ".join(missing)
    for name, variable in wanted["env"]:
        if name in values:
            env[variable] = values[name]
        else:
            env.pop(variable, None)
    if not wanted["file"] and not wanted["stdin"]:
        try:
            os.execvpe(command[0], command, env)
        except OSError as e:
            say(f"{command[0]}: {e.strerror}")
            return 127
    directory = tempfile.mkdtemp(prefix="dotfiles-credentials.", dir=runtime_dir())
    try:
        for name, variable in wanted["file"]:
            env.pop(variable, None)
            if name in values:
                write_private(directory, variable, values[name])
                env[variable] = os.path.join(directory, variable)
        stdin_name = wanted["stdin"][0][0] if wanted["stdin"] else None
        try:
            child = subprocess.Popen(command, env=env, stdin=subprocess.PIPE if stdin_name else None)
        except OSError as e:
            say(f"{command[0]}: {e.strerror}")
            return 127
        for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
            signal.signal(sig, lambda number, _: child.send_signal(number))
        if stdin_name:
            try:
                child.stdin.write(values.get(stdin_name, "").encode())
                child.stdin.close()
            except BrokenPipeError:
                pass
        code = child.wait()
    finally:
        shutil.rmtree(directory, ignore_errors=True)
    return 128 - code if code < 0 else code


def files(config, args):
    if len(args) < 1:
        say("files takes a directory and credential names")
        return 2
    directory, names = args[0], args[1:]
    shutil.rmtree(directory, ignore_errors=True)
    os.makedirs(directory, mode=0o700, exist_ok=True)
    os.chmod(directory, 0o700)
    for name in names:
        declared(config, name)
        value, said = resolve(config, name)
        if value:
            write_private(directory, name, value)
        else:
            say(f"{name} is unavailable, so its file is not written ({'; '.join(said)})")
    return 0


def why(config, args):
    if not args:
        say("why takes credential names")
        return 2
    for name in args:
        declared(config, name)
    rows = presence(config, args, None, True)
    for name in args:
        row = rows[name]
        reasons = "; ".join(f"{tier}: {said}" for tier, said in row["said"].items())
        where = f" from {row['tier']}" if row["tier"] else ""
        print(f"  {name}: {row['status']}{where}" + (f" ({reasons}). To add it, {manual(name, config['credentials'][name])}" if reasons else ""), file=sys.stderr)
    return 0


def presence(config, names, deadline, run_probes):
    rows, said, chains = {}, {}, {}
    for name in names:
        credential = config["credentials"][name]
        login, probe = credential["deliver"].get("login"), credential.get("probe")
        if login:
            if not probe or not run_probes:
                rows[name] = {"status": "not checked", "tier": None, "said": {"login": "not probed here"}}
                continue
            code, _, _ = call(["/bin/sh", "-c", probe], deadline or LIMIT)
            if code == 0:
                rows[name] = {"status": "present", "tier": "login", "said": {}}
            else:
                rows[name] = {"status": "missing", "tier": None, "said": {"login": f"not logged in; run: {login}"}}
            continue
        said[name], chains[name] = {}, tiers(config, credential)
    pending = list(chains)
    for depth in range(max([len(c) for c in chains.values()] + [0])):
        at = {name: chains[name][depth] for name in pending if depth < len(chains[name])}
        asked = Provider(config["runtime"]).presence([n for n, t in at.items() if isinstance(t, Provider)], deadline)
        for name, tier in at.items():
            if isinstance(tier, Provider):
                status, why = asked[name]
                found = status == "present"
                why = why if status in ("present", "missing") else f"{status}: {why}"
            else:
                value, why = tier.fetch(name)
                found = bool(value)
            if found:
                rows[name] = {"status": "present", "tier": tier.label, "said": {}}
                pending.remove(name)
            else:
                said[name][tier.label] = why
    for name in pending:
        rows[name] = {"status": "missing", "tier": None, "said": said[name]}
    return rows


def delivered(path, variable):
    try:
        with open(path) as f:
            for line in f:
                if line.startswith(variable + "="):
                    words = line[len(variable) + 1:].strip().strip("'\"").split()
                    return "read", {k for k in words if KEY.match(k)}
    except FileNotFoundError:
        return "absent", set()
    except (OSError, ValueError):
        return "unreadable", set()
    return "no key list", set()


def methods(credential):
    deliver = credential["deliver"]
    shown = []
    for method in ("file", "env", "stdin", "session", "keyring", "login"):
        value = deliver.get(method)
        if value is True:
            shown.append(method)
        elif value:
            shown.append(f"{method} {value}" if method in ("env", "session") else method)
    return ", ".join(shown) or "nothing"


def audit(report, config, args):
    as_json, deadline = False, None
    while args:
        word = args.pop(0)
        if word == "--json":
            as_json = True
        elif word == "--timeout" and args and re.fullmatch(r"[0-9]+(\.[0-9]+)?", args[0]) and float(args[0]) > 0:
            deadline = float(args.pop(0))
        else:
            say(f"audit takes --json and --timeout SECONDS, not {word}")
            return 2
    checked = config is not None
    names = sorted(report["credentials"])
    if checked:
        rows = presence(config, names, deadline, deadline is None)
    else:
        why = report["unconfigured"]
        rows = {name: {"status": "not checked", "tier": None,
                       "said": {"provider": f"provider not configured: {why}"} if why and not report["credentials"][name]["deliver"].get("login") else {}}
                for name in names}
    consumers = {}
    for name in names:
        credential = report["credentials"][name]
        consumer = credential["to"] or ", ".join(credential["solutions"])
        consumers.setdefault(consumer, []).append({
            "name": name, "description": credential["description"], "solutions": credential["solutions"],
            "methods": methods(credential), "manual": manual(name, credential), **rows[name]})
    if checked:
        state, keys = delivered(os.path.join(os.path.expanduser("~"), report["sessionFile"]), report["sessionKeys"])
        wanted = {c["deliver"]["session"] for c in report["credentials"].values() if c["deliver"].get("session")}
        session = {"file": report["sessionFile"], "state": state, "deliveredUndeclared": sorted(keys - wanted)}
    else:
        session = {"file": report["sessionFile"], "state": "not checked"}
    result = {"machine": report["machine"], "provider": report["provider"], "store": report.get("store"),
              "checked": checked, "consumers": [{"consumer": k, "credentials": v} for k, v in sorted(consumers.items())],
              "session": session}
    print(json.dumps(result, indent=2) if as_json else text(result))
    return 0


def text(result):
    lines = [f"Credentials by consumer (local store: {result['store'] or 'none'}, provider: {result['provider']})"]
    if not result["consumers"]:
        lines.append("  none declared")
    for consumer in result["consumers"]:
        rows = consumer["credentials"]
        lines.append(f"  {consumer['consumer']}  ({'; '.join(sorted({r['methods'] for r in rows}))})")
        width = max(len(r["name"]) for r in rows)
        for r in rows:
            where = f"  {r['tier']}" if r["tier"] else ""
            lines.append(f"    {r['name'].ljust(width)}  {r['status']}{where}")
            for tier, why in r["said"].items():
                lines.append(f"      {tier}: {why}")
            if r["status"] == "missing":
                lines.append(f"      to add it, {r['manual']}")
    session = result["session"]
    lines += ["", f"Session env file ~/{session['file']}: {session['state']}"]
    if "deliveredUndeclared" in session:
        lines.append("  delivered and undeclared: " + (" ".join(session["deliveredUndeclared"]) or "none"))
    if not result["checked"]:
        lines += ["", "Nothing was asked of any store or provider, and nothing was read from this home."]
    return "\n".join(lines)


def main(argv):
    report_path, runtime_path, command, *args = argv
    with open(report_path) as f:
        report = json.load(f)
    config = None
    if runtime_path != "-":
        with open(runtime_path) as f:
            config = {**report, **json.load(f)}
        if config.get("toolPath"):
            os.environ["PATH"] = os.environ.get("PATH", "/usr/bin:/bin") + ":" + config["toolPath"]
    if command == "audit":
        return audit(report, config, args)
    if config is None:
        say(f"{command} needs a machine's own build")
        return 2
    commands = {"get": get, "set": keep, "run": run, "files": files, "why": why}
    if command not in commands:
        say(f"unknown command {command}. Commands: {', '.join(sorted(commands))}, audit")
        return 2
    return commands[command](config, args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

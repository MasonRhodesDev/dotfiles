{ lib, pkgs, machines }:
pkgs.runCommand "check-no-secrets" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  python3 -I - ${lib.concatStringsSep " " (lib.mapAttrsToList (name: m: "${name}=${builtins.unsafeDiscardOutputDependency m.build.drvPath}") machines)} <<'EOF'
  import os, re, sys
  shapes = {
      "a Tailscale key": re.compile(rb"tskey-[a-z]+-[A-Za-z0-9]{6,}"),
      "a Bitwarden access token": re.compile(rb"0\.[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.[A-Za-z0-9]+:[A-Za-z0-9+/]+=*"),
  }
  stored = re.compile(rb"/nix/store/[a-z0-9]{32}-[^\"/\\\\\s]+")
  failed = False
  for arg in sys.argv[1:]:
      name, root = arg.split("=", 1)
      seen, todo, scanned = set(), [root.encode()], 0
      while todo:
          path = todo.pop()
          if path in seen or not os.path.isfile(path):
              continue
          seen.add(path)
          data = open(path, "rb").read()
          scanned += 1
          for what, shape in shapes.items():
              if shape.search(data):
                  print(f"FAIL {name}: {path.decode()} holds text shaped like {what}")
                  failed = True
          if path.endswith(b".drv"):
              todo.extend(stored.findall(data))
      print(f"{name}: {scanned} derivations and source files read")
  sys.exit(1 if failed else 0)
  EOF
  touch $out
''

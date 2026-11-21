{ lib, pkgs, stub, evalHome }:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  live = name: stub.${name}.secretsAudit;
  unchecked = name: stub.${name}.secretsUnchecked.${system};
  credentialOf = name: "${stub.${name}.configuration.config.dotfiles.credential}/bin/dotfiles-credential";

  fixture = (evalHome {
    owners = { "fixture-solution#home" = "fixture-solution"; };
    modules = [
      (lib.setDefaultModuleLocation "fixture-solution#home" ({ pkgs, ... }: {
        dotfiles.credentials."fixture/one".description = "A fixture secret.";
        dotfiles.credentialProvider.unconfigured = null;
        dotfiles.credentialProvider.has = pkgs.writeShellScript "fixture-presence" ''for name in "$@"; do printf '%s\n' "$name"; done'';
      }))
    ];
  }).config.dotfiles.secretsAudit;

  field = pkgs.writeText "field.py" ''
    import json, sys
    value = json.load(open(sys.argv[1]))
    steps = sys.argv[2].split(".")
    if steps[0] == "tailscale":
        value = [c for consumer in value["consumers"] for c in consumer["credentials"] if c["name"].startswith("tailscale/")][0]
        steps = steps[1:]
    for step in steps:
        value = value[int(step)] if step.isdigit() else value[step]
    print(json.dumps(value, sort_keys=True))
  '';
in
pkgs.runCommand "check-secrets-audit" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  set -u
  sentinel=SENTINEL-c0ffee-4242
  fakes=$TMPDIR/fakes
  fake=$TMPDIR/fake
  log=$TMPDIR/log
  scratch=$TMPDIR/home
  quiet=$TMPDIR/quiet
  mkdir -p "$fakes"

  cat > "$fakes/infisical" <<'EOF'
  #!${pkgs.runtimeShell}
  printf '%s\n' "infisical $*" >> "$LOG/argv"
  echo "infisical debug $SENTINEL" >&2
  case $1 in
    login)
      [ ! -e "$FAKE/slow" ] || sleep 60
      [ ! -e "$FAKE/refuse" ] || exit 1
      [ "''${INFISICAL_UNIVERSAL_AUTH_CLIENT_ID-}" = fixture-id ] && [ "''${INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET-}" = "client-$SENTINEL" ] || exit 1
      echo "token-$SENTINEL" ;;
    export)
      [ "''${INFISICAL_TOKEN-}" = "token-$SENTINEL" ] && [ ! -e "$FAKE/down" ] || exit 1
      case " $* " in *" --path /tailscale/work "*) ;; *) echo '[]'; exit 0 ;; esac
      if [ -e "$FAKE/held" ]; then
        printf '[{"key": "AUTHKEY", "value": "%s"}, {"key": "OTHER", "value": "%s"}]\n' "$SENTINEL" "$SENTINEL"
      else
        printf '[{"key": "AUTHKEY", "value": ""}, {"secretKey": "OTHER", "secretValue": "%s"}]\n' "$SENTINEL"
      fi ;;
    *) exit 1 ;;
  esac
  EOF
  cat > "$fakes/bws" <<'EOF'
  #!${pkgs.runtimeShell}
  printf '%s\n' "bws $*" >> "$LOG/argv"
  echo "bws debug $SENTINEL" >&2
  [ "''${BWS_ACCESS_TOKEN-}" = "token-$SENTINEL" ] && [ ! -e "$FAKE/down" ] || exit 1
  case $(cat "$FAKE/bws" 2>/dev/null) in
    held) printf '[{"key": "tailscale/work/authkey", "value": "%s"}, {"key": "OTHER", "value": "%s"}]\n' "$SENTINEL" "$SENTINEL" ;;
    twice) printf '[{"key": "tailscale/work/authkey", "value": "%s"}, {"key": "tailscale/work/authkey", "value": "%s"}]\n' "$SENTINEL" "$SENTINEL" ;;
    garbage) echo "not a list $SENTINEL" ;;
    *) printf '[{"key": "OTHER", "value": "%s"}]\n' "$SENTINEL" ;;
  esac
  EOF
  cat > "$fakes/secret-tool" <<'EOF'
  #!${pkgs.runtimeShell}
  printf '%s\n' "secret-tool $*" >> "$LOG/argv"
  [ "$1" = lookup ] && [ -e "$FAKE/keyring" ] || exit 1
  while IFS= read -r held; do [ "$held" != "$5" ] || { printf '%s' "$SENTINEL"; exit 0; }; done < "$FAKE/keyring"
  exit 1
  EOF
  cat > "$fakes/gh" <<'EOF'
  #!${pkgs.runtimeShell}
  printf '%s\n' "gh $*" >> "$LOG/argv"
  [ -e "$FAKE/gh-login" ] || exit 1
  [ "$1 $2" != "auth token" ] || printf '%s\n' "$SENTINEL"
  EOF
  cat > "$fakes/aws" <<'EOF'
  #!${pkgs.runtimeShell}
  printf '%s\n' "aws $*" >> "$LOG/argv"
  [ -e "$FAKE/aws-login" ] && [ "$*" = "sts get-caller-identity --profile bedrock-developer" ] && echo '{"Account": "000000000000"}'
  EOF
  chmod +x "$fakes"/*

  failures=0
  fail() {
    echo "FAIL $1"
    printf '%s\n' "$said" "$err" | sed 's/^/  said: /'
    sed 's/^/  call: /' "$log/argv" 2>/dev/null || true
    failures=$((failures + 1))
  }

  new_home() {
    chmod -R u+w "$scratch" "$fake" 2>/dev/null || true
    rm -rf "$scratch" "$fake"
    mkdir -p "$scratch/.config/infisical" "$scratch/.config/bitwarden" "$scratch/.config/fixture" "$fake"
    for flag in "$@"; do
      case $flag in
        infisical-identity) printf '%s\n' INFISICAL_CLIENT_ID=fixture-id "INFISICAL_CLIENT_SECRET=client-$sentinel" > "$scratch/.config/infisical/machine.env" ;;
        infisical-empty-secret) printf '%s\n' INFISICAL_CLIENT_ID=fixture-id "INFISICAL_CLIENT_SECRET=" > "$scratch/.config/infisical/machine.env" ;;
        bitwarden-token) echo "BWS_ACCESS_TOKEN=token-$sentinel" > "$scratch/.config/bitwarden/machine.env" ;;
        bws=*) echo "''${flag#bws=}" > "$fake/bws" ;;
        *) touch "$fake/$flag" ;;
      esac
    done
  }

  snapshot() {
    (cd "$scratch" && find . | sort && find . -type f -exec sha256sum {} + | sort)
  }

  run() {
    local before
    rm -rf "$log" "$quiet"
    mkdir -p "$log" "$quiet"
    before=$(snapshot)
    said=$(cd "$scratch" && env -i HOME="$scratch" TMPDIR="$quiet" LOG="$log" FAKE="$fake" SENTINEL="$sentinel" \
      PATH="$fakes:${pkgs.coreutils}/bin" "$@" 2> "$log/stderr") && status=0 || status=$?
    err=$(cat "$log/stderr")
    [ "$(snapshot)" = "$before" ] || fail "$*: writes nothing in the home"
    [ -z "$(ls -A "$quiet")" ] || fail "$*: writes no temporary file"
    case "$said$err" in *"$sentinel"*) fail "$*: no value reaches its output" ;; esac
    if grep -qF "$sentinel" "$log/argv" 2>/dev/null; then fail "$*: no value is on a command line it runs"; fi
  }

  is() { python3 -I ${field} <(printf '%s' "$said") "$1"; }
  expect() {
    local got
    got=$(is "$1" 2>&1) || got="(no $1: $got)"
    [ "$got" = "$2" ] || fail "$3: $1 should be $2, and is $got"
  }
  exits() { [ "$status" = "$1" ] || fail "$2: exits $1, not $status"; }
  untouched() { ! grep -q -e '^infisical' -e '^bws' "$log/argv" 2>/dev/null || fail "$1: asks no provider"; }
  unreachable() { case $(is tailscale.said.provider) in '"provider unreachable: '*) ;; *) fail "$1: the provider tier says it is unreachable" ;; esac; }
  unconfigured() { case $(is tailscale.said.provider) in '"provider not configured: '*) ;; *) fail "$1: the provider tier says it is not configured" ;; esac; }

  laptop=${live "stub-work-laptop"}
  desktop=${live "stub-gaming-desktop"}
  headless=${live "stub-headless"}
  bitwarden=${live "stub-bitwarden-server"}

  new_home infisical-identity held
  run "$laptop" --json
  expect tailscale.status '"present"' "infisical holds the secret"
  expect tailscale.name '"tailscale/work/authkey"' "the secret is named"
  expect tailscale.solutions '["tailscale"]' "the secret names the solution that declares it"
  expect provider '"infisical"' "the audit names the provider"
  expect checked true "a run on this machine"
  exits 0 "everything is present"
  grep -qx -- 'infisical export --format=json --silent --projectId example-project --env example-env --path /tailscale/work' "$log/argv" \
    || fail "presence reads the secret's folder in the machine's project"
  run "$laptop"
  grep -qx '  tailscale join (activation)  (file)' <<< "$said" && grep -qx '    tailscale/work/authkey  present  provider' <<< "$said" || fail "the text names the consumer, the secret, its status and the tier that answered"

  new_home infisical-identity held
  echo tailscale/work/authkey > "$fake/keyring"
  run "$laptop" --json
  expect tailscale.status '"present"' "the keyring holds the secret"
  expect tailscale.tier '"local store"' "the local store answers first"
  ! grep -q -- '^infisical export .*--path /tailscale/work' "$log/argv" || fail "with the secret in the keyring, the provider is never asked for it"

  login() { python3 -I -c 'import json, sys
  for c in json.load(open(sys.argv[1]))["consumers"]:
      for r in c["credentials"]:
          if r["name"] == sys.argv[2]:
              print(r["status"], r["tier"], json.dumps(r["said"]), c["consumer"])' <(printf '%s' "$said") "$1"; }
  new_home infisical-identity aws-login gh-login
  run "$laptop" --json
  [ "$(login aws/sso-bedrock)" = 'present login {} bedrock-harness' ] || fail "a login whose probe succeeds is present"
  [ "$(login github/cli)" = 'present login {} gh' ] || fail "gh's login is probed"
  [ "$(login github/packages-token)" = 'present derive {} npm' ] || fail "with gh logged in, the npm token is derived"
  new_home infisical-identity
  run "$laptop" --json
  [ "$(login aws/sso-bedrock)" = 'missing None {"login": "not logged in; run: aws sso login --profile bedrock-developer"} bedrock-harness' ] || fail "a login whose probe fails gives its login command"
  case $(login github/packages-token) in 'missing None '*'"derive": "gh auth token gave nothing (exit 1)"'*) ;; *) fail "without gh's login, derive says it gave nothing" ;; esac
  new_home infisical-identity aws-login gh-login
  run "$laptop" --timeout 5 --json
  [ "$(login aws/sso-bedrock)" = 'not checked None {"login": "not probed here"} bedrock-harness' ] || fail "dot plan runs no login probe"
  ! grep -q '^aws' "$log/argv" || fail "dot plan never runs aws"

  new_home infisical-identity
  run "$laptop" --json
  expect tailscale.status '"missing"' "infisical has the folder but an empty AUTHKEY"
  exits 0 "a missing secret"

  new_home infisical-identity refuse
  run "$laptop" --json
  expect tailscale.status '"missing"' "infisical refuses the login"; unreachable "infisical refuses the login"
  case $(is tailscale.said.provider) in *"refused the login"*) ;; *) fail "an unreachable provider says why" ;; esac
  exits 0 "an unreachable provider"

  new_home infisical-identity held slow
  started=$SECONDS
  run "$laptop" --timeout 1 --json
  waited=$((SECONDS - started))
  expect tailscale.status '"missing"' "a provider that does not answer within the deadline"; unreachable "a provider that does not answer within the deadline"
  expect tailscale.said.provider '"provider unreachable: the provider did not answer within 1 s"' "a provider past the deadline"
  exits 0 "a provider past the deadline"
  [ "$waited" -lt 10 ] || fail "the audit returns at its deadline, not at the provider's own 30 s limit, and took $waited s"

  new_home infisical-identity held
  run "$laptop" --timeout 30 --json
  expect tailscale.status '"present"' "a provider that answers within the deadline"

  run "$laptop" --timeout soon
  exits 2 "a deadline that is not a number of seconds"

  new_home infisical-identity held down
  run "$laptop" --json
  expect tailscale.status '"missing"' "infisical cannot export the folder"; unreachable "infisical cannot export the folder"
  exits 0 "a folder that cannot be read"

  new_home
  run "$laptop" --json
  expect tailscale.status '"missing"' "no machine.env"; unconfigured "no machine.env"
  case $(is tailscale.said.provider) in *"machine.env is missing"*) ;; *) fail "no machine.env says so" ;; esac
  untouched "no machine.env"
  exits 0 "no machine.env"

  new_home infisical-empty-secret held
  run "$laptop" --json
  expect tailscale.status '"missing"' "a machine.env with an empty client secret"; unconfigured "a machine.env with an empty client secret"
  untouched "a machine.env with an empty client secret"

  new_home infisical-identity held
  run "$desktop" --json
  expect tailscale.status '"missing"' "a machine with no Infisical project"; unconfigured "a machine with no Infisical project"
  case $(is tailscale.said.provider) in *"no Infisical project"*) ;; *) fail "no Infisical project says so" ;; esac
  untouched "a machine with no Infisical project"
  exits 0 "a machine with no Infisical project"

  new_home infisical-identity held bitwarden-token bws=held
  run "$headless" --json
  expect tailscale.status '"missing"' "a machine with secrets = none"; unconfigured "a machine with secrets = none"
  untouched "a machine with secrets = none"
  exits 0 "a machine with secrets = none"

  new_home bitwarden-token bws=held
  run "$bitwarden" --json
  expect tailscale.status '"present"' "bitwarden holds the secret"
  expect provider '"bitwarden"' "a bitwarden audit names its provider"
  exits 0 "bitwarden holds everything"
  grep -q '^bws secret list 00000000-0000-4000-8000-0000000000e2 ' "$log/argv" || fail "presence lists the machine's secrets project"

  new_home bitwarden-token bws=other
  run "$bitwarden" --json
  expect tailscale.status '"missing"' "bitwarden lacks the secret"
  exits 0 "bitwarden lacks the secret"

  new_home bitwarden-token bws=twice
  run "$bitwarden" --json
  expect tailscale.status '"missing"' "bitwarden holds two secrets of that name, which the provider refuses"

  new_home bitwarden-token bws=garbage
  run "$bitwarden" --json
  expect tailscale.status '"missing"' "bitwarden answers with something other than a list"; unreachable "bitwarden answers with something other than a list"

  new_home bitwarden-token bws=held down
  run "$bitwarden" --json
  expect tailscale.status '"missing"' "bws cannot list the project"; unreachable "bws cannot list the project"
  case $(is tailscale.said.provider) in *"could not list the Bitwarden project"*) ;; *) fail "an unreachable Bitwarden says why" ;; esac

  new_home bws=held
  run "$bitwarden" --json
  expect tailscale.status '"missing"' "no Bitwarden token"; unconfigured "no Bitwarden token"
  untouched "no Bitwarden token"

  new_home infisical-identity held
  run ${unchecked "stub-work-laptop"} --json
  expect tailscale.status '"not checked"' "another machine"
  expect checked false "another machine"
  expect session.state '"not checked"' "another machine's session env file"
  untouched "another machine"
  exits 0 "another machine"

  run ${unchecked "stub-gaming-desktop"} --json
  [ "$(login github/cli)" = 'not checked None {} gh' ] || fail "another machine's login names no provider reason, since a login never asks the provider"
  expect tailscale.status '"not checked"' "another machine with no Infisical project, known from the flake"; unconfigured "another machine with no Infisical project, known from the flake"
  untouched "another machine with no Infisical project"
  exits 0 "another machine with no Infisical project"

  new_home infisical-identity held
  mkdir -p "$scratch/.config/dotfiles"
  printf '%s\n' "export NODE_AUTH_TOKEN='$sentinel'" "export FIXTURE_EXTRA='$sentinel'" "__DOTFILES_KEYS='FIXTURE_EXTRA NODE_AUTH_TOKEN'" > "$scratch/.config/dotfiles/env.sh"
  run "$laptop" --json
  expect session '{"deliveredUndeclared": ["FIXTURE_EXTRA"], "file": ".config/dotfiles/env.sh", "state": "read"}' "the session file is read, and a key nothing declares is named"
  run "$laptop"
  grep -qx '  delivered and undeclared: FIXTURE_EXTRA' <<< "$said" || fail "the text lists a delivered key nothing declares"

  echo "export NODE_AUTH_TOKEN='$sentinel'" > "$scratch/.config/dotfiles/env.sh"
  run "$laptop" --json
  expect session.state '"no key list"' "a session file without its key list"

  rm "$scratch/.config/dotfiles/env.sh"
  run "$laptop" --json
  expect session.state '"absent"' "no session file"

  new_home
  run ${fixture} --json
  expect consumers.0.credentials.0.solutions '["fixture-solution"]' "a secret names the solution that declares it"

  run ${fixture} --verbose
  exits 2 "an audit that cannot run"

  store() {
    rm -rf "$log" && mkdir -p "$log"
    said=$(printf '%s\n' "$sentinel" | env -i HOME="$scratch" LOG="$log" FAKE="$fake" SENTINEL="$sentinel" PATH="$fakes:${pkgs.coreutils}/bin" "$@" 2>&1) && status=0 || status=$?
    case $said in *"$sentinel"*) fail "$*: set never prints the value" ;; esac
    if grep -qF "$sentinel" "$log/argv" 2>/dev/null; then fail "$*: set never puts the value on a command line"; fi
  }
  new_home
  store ${credentialOf "stub-headless"} set tailscale/personal/authkey
  exits 0 "set on a headless machine"
  stored=$scratch/.local/state/dotfiles/credentials/tailscale/personal/authkey
  [ "$(cat "$stored" 2>/dev/null)" = "$sentinel" ] || fail "set stores the value without its trailing newline in the headless file store"
  [ "$(stat -c %a "$stored" 2>/dev/null)" = 600 ] || fail "the stored file is mode 600"
  for dir in "$scratch/.local/state/dotfiles/credentials" "$scratch/.local/state/dotfiles/credentials/tailscale" "$scratch/.local/state/dotfiles/credentials/tailscale/personal"; do
    [ "$(stat -c %a "$dir")" = 700 ] || fail "$dir is mode 700"
  done
  value=$(env -i HOME="$scratch" PATH="${pkgs.coreutils}/bin" ${credentialOf "stub-headless"} get tailscale/personal/authkey)
  [ "$value" = "$sentinel" ] || fail "get reads back what set stored"
  store ${credentialOf "stub-headless"} set tailscale/work/authkey
  exits 2 "set refuses a name the machine does not declare"

  new_home
  cat > "$fakes/secret-tool" <<'EOF'
  #!${pkgs.runtimeShell}
  printf '%s\n' "secret-tool $*" >> "$LOG/argv"
  [ "$1" = store ] && cat > "$LOG/stdin"
  EOF
  store ${credentialOf "stub-work-laptop"} set tailscale/work/authkey
  exits 0 "set on a Linux desktop"
  grep -qx 'secret-tool store --label dotfiles tailscale/work/authkey service dotfiles account tailscale/work/authkey' "$log/argv" || fail "set stores into the keyring item service=dotfiles account=NAME"
  [ "$(cat "$log/stdin" 2>/dev/null)" = "$sentinel" ] || fail "secret-tool store reads the value on stdin"

  export HOME=$TMPDIR/dot-home USER=alex DOTFILES_FLAKE=$TMPDIR/flake
  generation=$TMPDIR/generation
  mkdir -p "$HOME" "$DOTFILES_FLAKE" "$generation/home-files" "$TMPDIR/dot-bin"
  touch "$DOTFILES_FLAKE/flake.nix" "$generation/activate"
  printf '#!/bin/sh\necho "LIVE $*"\necho "  tailscale/work/authkey  missing  (tailscale)"\nexit 1\n' > "$TMPDIR/live-audit"
  printf '#!/bin/sh\necho "UNCHECKED $*"\n' > "$TMPDIR/unchecked-audit"
  cp "$TMPDIR/live-audit" "$generation/dotfiles-secrets"
  cat > "$TMPDIR/dot-bin/nix" <<EOF
  #!/bin/sh
  echo "nix \$*" >> "$TMPDIR/nix-calls"
  case "\$*" in
    *"#lib.machines --raw"*) printf 'box other' ;;
    *"#lib.machines.box.system --raw"*) printf x86_64-linux ;;
    *"#lib.machines.other.system --raw"*) printf aarch64-darwin ;;
    *"#lib.machines.box.user --raw"*) printf 'alex\n%s' "$HOME" ;;
    *builtins.currentSystem*) printf x86_64-linux ;;
    build*"#lib.machines.box.secretsAudit") echo "$TMPDIR/live-audit" ;;
    build*"#lib.machines."*".secretsUnchecked.x86_64-linux") echo "$TMPDIR/unchecked-audit" ;;
    build*"#lib.machines.box.build"*) echo "$generation" ;;
    *) echo "nix stub: unexpected arguments: \$*" >&2; exit 2 ;;
  esac
  EOF
  chmod +x "$TMPDIR"/*-audit "$generation/dotfiles-secrets" "$TMPDIR/dot-bin/nix"
  dot() { PATH=$TMPDIR/dot-bin:${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin:${pkgs.gnused}/bin:${pkgs.findutils}/bin:${pkgs.gawk}/bin ${pkgs.bash}/bin/bash ${../dot} --private stub "$@" 2>&1; }
  err=

  said=$(dot --machine box secrets) && status=0 || status=$?
  [ "$said" = "UNCHECKED " ] || fail "dot --machine NAME secrets also builds the unchecked audit"
  said=$(dot secrets --machine other --json) && status=0 || status=$?
  [ "$said" = "UNCHECKED --json" ] || fail "dot secrets --machine builds the unchecked audit for this host's system and passes --json"
  exits 0 "dot secrets --machine passes the audit's exit"

  said=$(DOTFILES_MACHINE=box dot secrets) && status=0 || status=$?
  [ "$(head -n 1 <<< "$said")" = "LIVE " ] || fail "dot secrets on this machine runs the machine's own audit with the provider's full time"
  exits 1 "dot secrets passes an audit that fails through"

  said=$(DOTFILES_MACHINE=other dot secrets) && status=0 || status=$?
  case $said in *"for aarch64-darwin and this host is x86_64-linux"*) ;; *) fail "dot secrets refuses a live audit of a machine of another system" ;; esac
  exits 1 "a live audit of another system"

  said=$(dot secrets --verbose) && status=0 || status=$?
  case $said in *"secrets takes --machine NAME and --json"*) ;; *) fail "dot secrets refuses an unknown option" ;; esac

  said=$(DOTFILES_MACHINE=box dot plan) && status=0 || status=$?
  exits 0 "an audit that fails does not make plan fail"
  sed -n '/^Secrets$/,/^$/p' <<< "$said" | grep -qx '    tailscale/work/authkey  missing  (tailscale)' \
    || fail "plan shows the audit, indented, in its Secrets section"
  sed -n '/^Secrets$/,/^$/p' <<< "$said" | grep -qx '  LIVE --timeout 5' || fail "plan gives the provider 5 seconds"

  [ "$failures" = 0 ]
  touch $out
''

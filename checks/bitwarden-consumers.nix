{ dot, lib, pkgs, stub }:
let
  machine = stub.stub-bitwarden-server;
  withoutProjects = dot.machineFrom (import ../private-stub/identity.nix) "bitwarden-without-projects" "stub-bitwarden-server without projects"
    (let entry = import ../private-stub/machines/stub-bitwarden-server.nix; in entry // { private = removeAttrs entry.private [ "bitwarden" ]; });
  carried = m: pkgs.writeText "bitwarden-warnings-${m.name}" m.configuration.config.home.extraBuilderCommands;
  config = machine.configuration.config;
  join = pkgs.writeText "tailscale-join-bitwarden" config.home.activation.tailscaleJoin.data;
  project = config.home.file.".config/bitwarden/project.json".source;
  exec = config.home.file.".local/bin/bitwarden-exec".source;
  sync = config.dotfiles.sessionSource;
  env = lib.escapeShellArg machine.private.bitwarden.envProject;
  secrets = lib.escapeShellArg machine.private.bitwarden.secretsProject;
in
pkgs.runCommand "check-bitwarden-consumers" { } ''
  set -u
  token=0.00000000-0000-4000-8000-00000000f1f1.fixtureClientSecret0123:Zml4dHVyZS1lbmNyeXB0aW9uLWtleQ==
  key=fixture-auth-key-0123456789
  fakes=$TMPDIR/fakes
  log=$TMPDIR/log
  api=$TMPDIR/api
  scratch=$TMPDIR/scratch
  mkdir -p "$fakes/with" "$fakes/without"

  cat > "$fakes/with/bws" <<'EOF'
  #!${pkgs.runtimeShell}
  echo "bws $*" >> "$LOG/calls"
  for v in BWS_SERVER_URL BWS_PROFILE BWS_CONFIG_FILE; do [ -z "''${!v+x}" ] || echo "$v" >> "$LOG/leaked"; done
  [ -n "''${BWS_ACCESS_TOKEN-}" ] && echo seen >> "$LOG/token"
  [ "''${BWS_ACCESS_TOKEN-}" = "$(cat "$API/token")" ] || { echo "Error: unauthorized" >&2; exit 1; }
  [ ! -e "$API/offline" ] || { echo "Error: error sending request" >&2; exit 1; }
  [ "$1 $2" = "secret list" ] || exit 2
  [ -r "$API/$3.json" ] || { echo "Error: 404 Not Found" >&2; exit 1; }
  cat "$API/$3.json"
  EOF
  cat > "$fakes/without/tailscale" <<'EOF'
  #!${pkgs.runtimeShell}
  echo "tailscale $*" >> "$LOG/calls"
  case $1 in
    status) echo '{"BackendState": "NeedsLogin"}' ;;
    switch) echo '[]' ;;
    login) for a in "$@"; do case $a in --auth-key=file:*) cat "''${a#--auth-key=file:}" > "$LOG/key" ;; esac; done ;;
  esac
  EOF
  cat > "$fakes/without/show" <<'EOF'
  #!${pkgs.runtimeShell}
  printf '%s\n' "$@" > "$LOG/argv"
  ${pkgs.coreutils}/bin/env > "$LOG/env"
  EOF
  chmod +x "$fakes"/*/*
  cp "$fakes/without/"* "$fakes/with/"

  failures=0
  fail() { echo "FAIL $1"; echo "  said: $said"; sed 's/^/  call: /' "$log/calls" 2>/dev/null || true; failures=$((failures + 1)); }

  api() {
    rm -rf "$api" && mkdir -p "$api"
    printf '%s' "$token" > "$api/token"
    printf '%s\n' '[{"key": "FIXTURE_KEY", "value": "fixture value"}, {"key": "not-a-name", "value": "x"}, {"key": "PATH", "value": "/fixture"}]' > "$api/"${env}.json
    case $1 in
      ok) echo "[{\"key\": \"tailscale/work/authkey\", \"value\": \"$key\"}, {\"key\": \"OTHER\", \"value\": \"x\"}]" ;;
      absent) echo '[{"key": "OTHER", "value": "x"}]' ;;
      empty) echo '[{"key": "tailscale/work/authkey", "value": ""}]' ;;
      duplicate) echo "[{\"key\": \"tailscale/work/authkey\", \"value\": \"$key\"}, {\"key\": \"tailscale/work/authkey\", \"value\": \"other\"}]" ;;
      missing) rm "$api/"${env}.json ;;
      offline) touch "$api/offline" ;;
    esac > "$api/"${secrets}.json
    [ "$1" != missing ] || rm "$api/"${secrets}.json
  }
  home() {
    rm -rf "$log" "$scratch" "$TMPDIR/run"
    mkdir -p "$log" "$scratch/.config/bitwarden" "$TMPDIR/run"
    chmod 700 "$TMPDIR/run"
    [ "''${2-}" = no-project ] || cp ${project} "$scratch/.config/bitwarden/project.json"
    case $1 in
      yes) printf '%s\n' BWS_SERVER_URL=https://machine-env.example.invalid "BWS_ACCESS_TOKEN = '$token'" BWS_PROFILE=machine-env > "$scratch/.config/bitwarden/machine.env" ;;
      empty) printf '%s\n' BWS_ACCESS_TOKEN= > "$scratch/.config/bitwarden/machine.env" ;;
      exported) printf '%s\n' "  export BWS_ACCESS_TOKEN='$token'" > "$scratch/.config/bitwarden/machine.env" ;;
    esac
  }
  run() {
    local limit=$1 bin=$2; shift 2
    said=$(cd "$scratch" && HOME=$scratch XDG_RUNTIME_DIR=$TMPDIR/run LOG=$log API=$api BITWARDEN_SYNC_INTERVAL=1 \
      BWS_SERVER_URL=https://caller.example.invalid PATH=$fakes/$bin:${pkgs.coreutils}/bin \
      ${pkgs.coreutils}/bin/timeout "$limit" "$@" 2>&1) && status=0 || status=$?
  }
  private() {
    ! grep -q -e "$token" -e "$key" -e 'fixture value' "$log/calls" 2>/dev/null || fail "$1: neither the token nor a secret is on a command line"
    case $said in *"$token"* | *"$key"* | *"fixture value"*) fail "$1: neither the token nor a secret is printed" ;; esac
    [ ! -s "$log/leaked" ] || fail "$1: bws never sees $(tr '\n' ' ' < "$log/leaked")"
  }
  served() {
    [ -s "$log/token" ] || fail "$1: bws gets the token from machine.env in its environment"
    grep -q -- "--server-url https://vault.example.invalid" "$log/calls" || fail "$1: bws talks to the server in the private entry"
    private "$1"
  }

  warned() {
    rm -rf "$TMPDIR/generation"
    mkdir -p "$TMPDIR/generation"
    (out=$TMPDIR/generation; . "$1")
    said=$(cat "$TMPDIR/generation/dotfiles-warnings" 2>/dev/null || true)
  }
  warned ${carried machine}
  [ -z "$said" ] || fail "a machine with Bitwarden projects carries no warning"
  warned ${carried withoutProjects}
  [ "$(wc -l <<< "$said")" = 1 ] && grep -q "^bitwarden-without-projects: .*private.bitwarden.envProject.*private.bitwarden.secretsProject" <<< "$said" \
    || fail "a machine with Bitwarden secrets and no projects carries one warning that names it and both keys"

  said=$(cat ${project})
  [ "$said" = '{"envProject":'"\"$(echo ${env})\""'}' ] || fail "project.json holds the env project from the private entry and nothing else"

  activate() { run 60 "$1" ${pkgs.bash}/bin/bash -c "set -euo pipefail; source ${join}"; }
  manual() {
    [ "$status" = 0 ] || fail "$1: activation exits $status"
    case $said in *"$2"*"To join the work tailnet by hand, run: tailscale login --nickname=work"*) ;; *) fail "$1: the manual login is printed after '$2'" ;; esac
    ! grep -q '^tailscale login' "$log/calls" 2>/dev/null || fail "$1: no login is attempted"
    private "$1"
  }

  api ok; home yes
  activate with
  [ "$status" = 0 ] || fail "the key is fetched: activation exits $status"
  [ "$(cat "$log/key" 2>/dev/null)" = "$key" ] || fail "the key from Bitwarden reaches tailscale login intact"
  grep -q -- "^bws secret list $(echo ${secrets}) " "$log/calls" || fail "the provider lists only the secrets project"
  ! grep -q -- "^bws secret list $(echo ${env})" "$log/calls" || fail "the provider never reads the env project"
  case $said in *"joined the work tailnet"*) ;; *) fail "the join is reported" ;; esac
  served "the provider"

  api ok; home yes
  activate without
  manual "bws is missing" "the bws CLI is not installed"

  api ok; home no
  activate with
  manual "no machine.env" "not logged in to Bitwarden Secrets Manager"
  [ ! -e "$log/calls" ] || ! grep -q '^bws' "$log/calls" || fail "no machine.env: bws never runs"

  api ok; home empty
  activate with
  manual "an empty token" "machine.env sets no BWS_ACCESS_TOKEN, so Bitwarden Secrets Manager is not asked"
  [ ! -e "$log/calls" ] || ! grep -q '^bws' "$log/calls" || fail "an empty token: bws never runs"

  api ok; home exported
  activate with
  [ "$(cat "$log/key" 2>/dev/null)" = "$key" ] || fail "a token on an export line, as the Infisical loader reads it, is used"
  served "an exported token"

  api offline; home yes
  activate with
  manual "offline" "could not list the Bitwarden project"

  api missing; home yes
  activate with
  manual "a wrong project" "could not list the Bitwarden project"

  api ok; home yes; printf '%s' wrong-token > "$api/token"
  activate with
  manual "a refused token" "could not list the Bitwarden project"

  api absent; home yes
  activate with
  manual "the secret is absent" "Bitwarden has no tailscale/work/authkey in the project"

  api empty; home yes
  activate with
  manual "the secret is empty" "Bitwarden has no tailscale/work/authkey in the project"

  api duplicate; home yes
  activate with
  manual "the secret is named twice" "Bitwarden has 2 secrets named tailscale/work/authkey"

  api ok; home yes
  run 5 with ${pkgs.bash}/bin/bash -c "exec ${sync} > $TMPDIR/sent"
  [ "$status" = 124 ] || fail "env sync keeps running, not exit $status"
  [ "$(grep -c '^{' "$TMPDIR/sent")" = 1 ] && grep -qx '{"FIXTURE_KEY": "fixture value"}' "$TMPDIR/sent" \
    || fail "env sync sends the env project's usable keys once as JSON, and skips PATH and not-a-name"
  [ -z "$(ls -A "$scratch/.config/bitwarden" | grep -v -e machine.env -e project.json)" ] || fail "env sync writes no file of its own"
  ! grep -q -- "^bws secret list $(echo ${secrets})" "$log/calls" || fail "env sync never reads the secrets project"
  served "env sync"

  idle() {
    [ "$status" = 124 ] || fail "$1: env sync stays up and idle, not exit $status"
    [ "$(grep -c -- "$2" <<< "$said")" = 1 ] || fail "$1: env sync says '$2' once"
    ! grep -q '^{' <<< "$said" || fail "$1: env sync sends nothing"
    private "$1"
  }
  for mode in "without yes ok:the bws CLI is not installed" "with no ok:not logged in to Bitwarden Secrets Manager" \
      "with empty ok:sets no BWS_ACCESS_TOKEN" "with yes offline:could not list the Bitwarden project" "with yes missing:could not list the Bitwarden project"; do
    read -r bin creds state <<< "''${mode%%:*}"
    api "$state"; home "$creds"
    run 5 "$bin" ${sync}
    idle "env sync with $bin bws, $creds token, $state API" "''${mode#*:}"
  done
  api ok; home yes no-project
  run 5 with ${sync}
  idle "env sync without project.json" "no Bitwarden env project for this machine"

  api ok; home yes
  run 10 with ${exec} show "two words" --flag
  [ "$status" = 0 ] || fail "bitwarden-exec runs the command, not $status"
  [ "$(cat "$log/argv" 2>/dev/null)" = "$(printf '%s\n' "two words" --flag)" ] || fail "bitwarden-exec keeps the command's arguments intact"
  grep -qx 'FIXTURE_KEY=fixture value' "$log/env" 2>/dev/null || fail "bitwarden-exec gives the command the env project's secrets"
  ! grep -q -e '^BWS_ACCESS_TOKEN=' -e "$token" "$log/env" 2>/dev/null || fail "bitwarden-exec never hands the token to the command"
  grep -qx 'PATH=.*' "$log/env" && ! grep -qx 'PATH=/fixture' "$log/env" || fail "bitwarden-exec never takes PATH from Bitwarden"
  served "bitwarden-exec"

  for mode in "without yes ok:the bws CLI is not installed" "with no ok:not logged in to Bitwarden Secrets Manager" \
      "with empty ok:sets no BWS_ACCESS_TOKEN" "with yes offline:could not list the Bitwarden project"; do
    read -r bin creds state <<< "''${mode%%:*}"
    api "$state"; home "$creds"
    run 10 "$bin" ${exec} show
    [ "$status" = 3 ] || fail "bitwarden-exec with $bin bws, $creds token, $state API exits 3, not $status"
    case $said in *"''${mode#*:}"*) ;; *) fail "bitwarden-exec with $bin bws, $creds token, $state API says why" ;; esac
    [ ! -e "$log/argv" ] || fail "bitwarden-exec with $bin bws, $creds token, $state API never runs the command"
  done

  [ "$failures" = 0 ]
  touch $out
''

{ pkgs, stub }:
let
  step = name: pkgs.writeText "tailscale-join-${name}" stub.${name}.configuration.config.home.activation.tailscaleJoin.data;
in
pkgs.runCommand "check-tailscale-join" { } ''
  set -u
  key=fixture-auth-key-0123456789
  client=fixture-client-secret-9876543210
  fakes=$TMPDIR/fakes
  log=$TMPDIR/log
  mkdir -p "$fakes/with" "$fakes/without"

  cat > "$fakes/without/tailscale" <<'EOF'
  #!${pkgs.runtimeShell}
  echo "tailscale $*" >> "$LOG/calls"
  case $1 in
    status) [ "$TS_STATE" = down ] && exit 1; echo "{\"BackendState\": \"$TS_STATE\"''${TS_TAILNET:+, \"CurrentTailnet\": {\"Name\": \"$TS_TAILNET\"}}}" ;;
    switch) echo "$TS_ACCOUNTS" ;;
    login)
      for a in "$@"; do case $a in --auth-key=file:*) f=''${a#--auth-key=file:}; cat "$f" > "$LOG/key"; stat -c %a "$f" > "$LOG/mode"; echo "$f" > "$LOG/file" ;; esac; done
      [ "$TS_LOGIN" = ok ] || { echo "backend error: invalid key"; exit 1; } ;;
  esac
  EOF
  cat > "$fakes/with/infisical" <<'EOF'
  #!${pkgs.runtimeShell}
  echo "infisical $*" >> "$LOG/calls"
  for v in INFISICAL_PROJECT_ID INFISICAL_ENV INFISICAL_PATH; do [ -z "''${!v+x}" ] || echo "$v" >> "$LOG/leaked"; done
  case $1 in
    login)
      [ "''${INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET-}" = "$CLIENT" ] || exit 1
      [ "$INF_LOGIN" = ok ] || exit 1
      echo fixture-token ;;
    export)
      [ "''${INFISICAL_TOKEN-}" = fixture-token ] || exit 1
      [ "$INF_EXPORT" = offline ] && exit 1
      case "$*" in *"--projectId example-project --env example-env --path /tailscale/work"*) ;; *) echo '[]'; exit 0 ;; esac
      [ "$INF_EXPORT" = absent ] && { echo '[{"key": "OTHER", "value": "x"}]'; exit 0; }
      echo "[{\"key\": \"AUTHKEY\", \"value\": \"$KEY\"}]" ;;
  esac
  EOF
  cat > "$fakes/without/secret-tool" <<'EOF'
  #!${pkgs.runtimeShell}
  echo "secret-tool $*" >> "$LOG/calls"
  [ "$1 $2 $3 $4 $5" = "lookup service dotfiles account tailscale/$KR_PROFILE/authkey" ] || exit 1
  case $KR in
    held) printf '%s' "$KEY-from-keyring" ;;
    locked) echo "Cannot unlock the collection" >&2; exit 1 ;;
    *) exit 1 ;;
  esac
  EOF
  chmod +x "$fakes"/*/*
  cp "$fakes/without/tailscale" "$fakes/without/secret-tool" "$fakes/with/"

  failures=0
  fail() { echo "FAIL $1"; echo "  said: $said"; cat "$log/calls" 2>/dev/null | sed 's/^/  call: /'; failures=$((failures + 1)); }
  run() {
    local bin=$2
    rm -rf "$log" "$TMPDIR/scratch" "$TMPDIR/run"
    mkdir -p "$log" "$TMPDIR/scratch/.config/infisical" "$TMPDIR/run"
    chmod 700 "$TMPDIR/run"
    case $CREDENTIALS in
      yes) printf '%s\n' INFISICAL_CLIENT_ID=fixture-id "INFISICAL_CLIENT_SECRET=$client" > "$TMPDIR/scratch/.config/infisical/machine.env" ;;
      with-project) printf '%s\n' INFISICAL_PROJECT_ID=machine-env-project "INFISICAL_CLIENT_ID = 'fixture-id'" INFISICAL_ENV=machine-env-env "INFISICAL_CLIENT_SECRET=\"$client\"" INFISICAL_PATH=/machine-env > "$TMPDIR/scratch/.config/infisical/machine.env" ;;
    esac
    if [ -n "$STORED" ]; then
      mkdir -p "$TMPDIR/scratch/.local/state/dotfiles/credentials/tailscale/personal"
      printf '%s\n' "$key-from-file" > "$TMPDIR/scratch/.local/state/dotfiles/credentials/tailscale/personal/authkey"
      chmod "$STORED" "$TMPDIR/scratch/.local/state/dotfiles/credentials/tailscale/personal/authkey"
    fi
    said=$(HOME=$TMPDIR/scratch XDG_RUNTIME_DIR=$TMPDIR/run LOG=$log KEY=$key CLIENT=$client PATH=$fakes/$bin:${pkgs.coreutils}/bin \
      ${pkgs.bash}/bin/bash -c "set -euo pipefail; source $1" 2>&1) && status=0 || status=$?
  }
  defaults() { TS_STATE=NeedsLogin TS_TAILNET= TS_ACCOUNTS='[]' TS_LOGIN=ok INF_LOGIN=ok INF_EXPORT=ok CREDENTIALS=yes KR=missing KR_PROFILE=work STORED=; unset DRY_RUN; }
  export TS_STATE TS_TAILNET TS_ACCOUNTS TS_LOGIN INF_LOGIN INF_EXPORT KR KR_PROFILE
  untouched() {
    [ "$status" = 0 ] || fail "$1: activation exits $status"
    ! grep -q -e '^infisical' -e '^tailscale login' -e '^tailscale switch [^-]' "$log/calls" 2>/dev/null || fail "$1: the machine is never switched or logged in"
  }
  manual() {
    [ "$status" = 0 ] || fail "$1: activation exits $status"
    case $said in *"$2"*"To join the $3 tailnet by hand, run: tailscale login --nickname=$3"*) ;; *) fail "$1: the manual login is printed after '$2'" ;; esac
    ! grep -q '^tailscale login' "$log/calls" 2>/dev/null || fail "$1: no login is attempted"
    [ -z "$(ls -A "$TMPDIR/run")" ] || fail "$1: nothing is left in the runtime directory"
  }

  laptop=${step "stub-work-laptop"}
  noproject=${step "stub-gaming-desktop"}
  none=${step "stub-headless"}

  defaults
  run $laptop with
  [ "$status" = 0 ] || fail "the key is fetched: activation exits $status"
  [ "$(cat "$log/key" 2>/dev/null)" = "$key" ] || fail "the key from Infisical reaches tailscale login intact"
  [ "$(cat "$log/mode" 2>/dev/null)" = 600 ] || fail "the key file is mode 600"
  case $(cat "$log/file" 2>/dev/null) in "$TMPDIR/run/"*) ;; *) fail "the key file is in the private runtime directory" ;; esac
  [ ! -e "$(cat "$log/file" 2>/dev/null)" ] && [ -z "$(ls -A "$TMPDIR/run")" ] || fail "the key file is gone after the login"
  grep -q -- '^tailscale login .*--nickname=work' "$log/calls" || fail "the login names the work profile"
  ! grep -q -e "$key" -e "$client" "$log/calls" || fail "neither the key nor the client secret is on a command line"
  case $said in *"$key"*) fail "the key is not printed" ;; esac
  case $said in *"joined the work tailnet"*) ;; *) fail "the join is reported" ;; esac

  defaults; KR=held
  run $laptop with
  [ "$status" = 0 ] && [ "$(cat "$log/key" 2>/dev/null)" = "$key-from-keyring" ] || fail "the local store comes first: the keyring's key reaches tailscale login"
  ! grep -q '^infisical' "$log/calls" || fail "the local store comes first: with the key in the keyring, Infisical is never asked"
  ! grep -q -e "$key" "$log/calls" || fail "the keyring's key is never on a command line"

  defaults; KR=locked
  run $laptop with
  [ "$status" = 0 ] && [ "$(cat "$log/key" 2>/dev/null)" = "$key" ] || fail "a locked keyring falls through to the provider"

  defaults; STORED=600
  run $none with
  [ "$status" = 0 ] && [ "$(cat "$log/key" 2>/dev/null)" = "$key-from-file" ] || fail "with no provider, a 0600 file in the headless local store joins the tailnet"
  case $said in *"$key"*) fail "the stored key is not printed" ;; esac

  defaults; STORED=644
  run $none with
  manual "a stored key others can read" "credentials/tailscale/personal/authkey is readable by others, so it is not used" personal

  defaults
  run $none with
  manual "secrets = none" "this machine has no secrets provider" personal
  case $said in *"local store: no file ~/.local/state/dotfiles/credentials/tailscale/personal/authkey"*"run: dotfiles-credential set tailscale/personal/authkey"*) ;; *) fail "secrets = none: every tier says why, and the step that fixes it is printed" ;; esac
  ! grep -q '^infisical' "$log/calls" || fail "secrets = none never runs infisical"

  defaults
  run $laptop without
  manual "the infisical CLI is missing" "the infisical CLI is not installed" work

  defaults; CREDENTIALS=no
  run $laptop with
  manual "no machine identity" "not logged in to Infisical" work

  defaults; INF_LOGIN=refused
  run $laptop with
  manual "the login is refused or offline" "Infisical refused the login or could not be reached" work

  defaults; INF_EXPORT=offline
  run $laptop with
  manual "the export fails" "could not read /tailscale/work from Infisical" work

  defaults; INF_EXPORT=absent
  run $laptop with
  manual "the secret is absent" "Infisical has no AUTHKEY in /tailscale/work" work

  defaults
  run $noproject with
  manual "no project in the private entry" "no Infisical project for this machine" personal
  ! grep -q '^infisical' "$log/calls" || fail "no project: infisical never runs"

  defaults; TS_LOGIN=refused
  run $laptop with
  [ "$status" = 0 ] || fail "tailscale refuses the key: activation exits $status"
  case $said in *"login with the work auth key failed: backend error: invalid key"*"run: tailscale login --nickname=work"*) ;; *) fail "tailscale refuses the key: its reason and the manual login are printed" ;; esac
  [ -z "$(ls -A "$TMPDIR/run")" ] || fail "tailscale refuses the key: the key file is gone"

  defaults; TS_STATE=down
  run $laptop with
  manual "tailscaled is down" "tailscaled is not answering" work

  defaults
  rm "$fakes/without/tailscale"
  run $laptop without
  [ "$status" = 0 ] || fail "no tailscale CLI: activation exits $status"
  case $said in *"the tailscale CLI is not installed"*"tailscale login --nickname=work"*) ;; *) fail "no tailscale CLI: the manual login is printed" ;; esac
  cp "$fakes/with/tailscale" "$fakes/without/"

  defaults; CREDENTIALS=no TS_ACCOUNTS='[{"id": "a1", "nickname": "personal"}, {"id": "b2", "nickname": "work"}]'
  run $laptop with
  [ "$status" = 0 ] || fail "a known work account: activation exits $status"
  case $said in *"run: tailscale switch b2"*) ;; *) fail "a known work account: the manual step is tailscale switch to it" ;; esac

  for state in Running Stopped Starting; do
    for machine in $laptop $noproject; do
      defaults; TS_STATE=$state
      run $machine with
      [ "$status" = 0 ] && [ -z "$said" ] || fail "$state: activation is quiet and succeeds"
      ! grep -q -e '^infisical' -e '^tailscale login' -e '^tailscale switch' "$log/calls" || fail "$state: a logged-in machine is left alone"
    done
  done

  accounts='[{"id": "a1", "nickname": "elsewhere", "tailnet": "other.example.invalid", "selected": true}, {"id": "c3", "nickname": "home", "tailnet": "example-personal.example.invalid"}]'

  defaults; TS_STATE=Running TS_TAILNET=other.example.invalid TS_ACCOUNTS=$accounts
  run $noproject with
  untouched "on another tailnet"
  case $said in *"logged in to the tailnet other.example.invalid, not the personal tailnet example-personal.example.invalid"*"run: tailscale switch c3"*) ;; *) fail "on another tailnet: the warning names both tailnets and the switch to the known account" ;; esac

  defaults; TS_STATE=Stopped TS_TAILNET=other.example.invalid
  run $noproject with
  untouched "on another tailnet with no account on its own"
  case $said in *"not the personal tailnet example-personal.example.invalid"*"run: tailscale login --nickname=personal"*) ;; *) fail "on another tailnet with no account on its own: the warning gives the login" ;; esac

  defaults; TS_STATE=Running TS_TAILNET=other.example.invalid TS_ACCOUNTS='[{"id": "s1", "nickname": "personal", "tailnet": "other.example.invalid", "selected": true}]'
  run $noproject with
  untouched "on another tailnet under the profile's own nickname"
  case $said in *"not the personal tailnet example-personal.example.invalid"*"run: tailscale login --nickname=personal"*) ;; *) fail "on another tailnet under the profile's own nickname: the warning gives the login, not a switch to the account it is on" ;; esac

  defaults; TS_STATE=Running TS_TAILNET=example-personal.example.invalid TS_ACCOUNTS=$accounts
  run $noproject with
  untouched "on its own tailnet"
  [ -z "$said" ] || fail "on its own tailnet: activation is quiet"

  defaults; TS_STATE=Running TS_TAILNET=other.example.invalid TS_ACCOUNTS=$accounts
  run $laptop with
  untouched "no tailnet stated for the profile"
  [ -z "$said" ] || fail "no tailnet stated for the profile: activation is quiet"
  ! grep -q '^tailscale switch' "$log/calls" || fail "no tailnet stated for the profile: no account is looked up"

  defaults; CREDENTIALS=with-project
  run $laptop with
  [ "$status" = 0 ] && [ "$(cat "$log/key" 2>/dev/null)" = "$key" ] || fail "machine.env names a project: the key is still fetched"
  grep -q -- '--projectId example-project --env example-env --path /tailscale/work' "$log/calls" || fail "machine.env names a project: the export reads the private entry's project and environment"
  [ ! -s "$log/leaked" ] || fail "machine.env names a project: infisical never sees $(tr '\n' ' ' < "$log/leaked")"

  defaults; CREDENTIALS=with-project
  run $noproject with
  manual "no project in the private entry, one in machine.env" "no Infisical project for this machine" personal
  ! grep -q '^infisical' "$log/calls" || fail "a project in machine.env alone never runs infisical"

  defaults
  said=$(PATH=$fakes/with:${pkgs.coreutils}/bin LOG=$log ${stub.stub-work-laptop.configuration.config.dotfiles.credential}/bin/dotfiles-credential get tailscale/personal/authkey 2>&1) && status=0 || status=$?
  [ "$status" = 2 ] || fail "a secret the machine did not declare is refused: exit $status"
  ! grep -q '^infisical' "$log/calls" 2>/dev/null || fail "a secret the machine did not declare never reaches the provider"

  defaults; export DRY_RUN=1
  run $laptop with
  [ "$status" = 0 ] && [ ! -e "$log/calls" ] || fail "a dry run touches nothing"
  unset DRY_RUN

  [ "$failures" = 0 ]
  touch $out
''

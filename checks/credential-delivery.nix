{ lib, pkgs, stub, evalHome }:
let
  laptop = stub.stub-work-laptop.configuration.config;
  slack = laptop.home.file.".local/bin/slack-mcp".source;

  fixture = (evalHome {
    modules = [
      ({ config, pkgs, ... }: {
        dotfiles.credentials = {
          "fixture/env" = { description = "A value the consumer reads from its environment."; deliver.env = "FIXTURE_ENV"; };
          "fixture/file" = { description = "A value the consumer reads from a file."; deliver.file = "FIXTURE_FILE"; };
          "fixture/stdin" = { description = "A value the consumer reads on stdin."; deliver.stdin = true; };
        };
        home.file.consumer.source = pkgs.writeShellScript "fixture-consumer"
          ''exec ${config.dotfiles.withCredentials [ "fixture/env" "fixture/file" "fixture/stdin" ]} "$CONSUMER" "$@"'';
        dotfiles.services.fixture-service = { command = [ "fixture" ]; credentials = [ "fixture/file" ]; };
      })
    ];
  }).config;
  consumer = fixture.home.file.consumer.source;
  unit = fixture.systemd.user.services.fixture-service.Service;
  agent = fixture.dotfiles.launchd.fixture-service.ProgramArguments;
  credential = "${fixture.dotfiles.credential}/bin/dotfiles-credential";
  writerArgs = name: let c = stub.${name}.configuration.config.dotfiles.services.dotfiles-session-env.command; in
    lib.escapeShellArg "${lib.escapeShellArgs [ (lib.elemAt c 0) (lib.elemAt c 1) ]} \"$SOURCE\" ${lib.escapeShellArgs [ (lib.elemAt c 3) (lib.elemAt c 4) (lib.elemAt c 5) ]}";
in
pkgs.runCommand "check-credential-delivery" { } ''
  set -u
  sentinel=SENTINEL-d311-7e57
  fakes=$TMPDIR/fakes
  log=$TMPDIR/log
  scratch=$TMPDIR/home
  run=$TMPDIR/run
  mkdir -p "$fakes"

  cat > "$fakes/secret-tool" <<'EOF'
  #!${pkgs.runtimeShell}
  printf '%s\n' "secret-tool $*" >> "$LOG/argv"
  [ "$1" = lookup ] || exit 1
  while IFS='=' read -r name value; do
    [ "$name" != "$5" ] || { printf '%s' "$value-$SENTINEL"; exit 0; }
  done < "$FAKE/keyring"
  exit 1
  EOF
  cat > "$fakes/npx" <<'EOF'
  #!${pkgs.runtimeShell}
  printf '%s\n' "npx $*" >> "$LOG/argv"
  for var in SLACK_MCP_XOXP_TOKEN SLACK_MCP_XOXC_TOKEN SLACK_MCP_XOXD_TOKEN; do
    eval "value=\''${$var-unset}"
    case $value in unset) echo "$var unset" ;; *"-$SENTINEL") echo "$var ''${value%%-*}" ;; *) echo "$var other" ;; esac
  done > "$LOG/seen"
  EOF
  cat > "$fakes/consumer" <<'EOF'
  #!${pkgs.runtimeShell}
  printf '%s\n' "consumer $*" >> "$LOG/argv"
  {
    [ "''${FIXTURE_ENV-}" = "env-$SENTINEL" ] && echo "env delivered"
    [ -n "''${FIXTURE_FILE-}" ] && [ "$(cat "$FIXTURE_FILE")" = "file-$SENTINEL" ] && echo "file delivered $(stat -c %a "$FIXTURE_FILE") $(stat -c %a "$(dirname "$FIXTURE_FILE")")"
    [ "$(cat)" = "stdin-$SENTINEL" ] && echo "stdin delivered"
    echo "missing ''${DOTFILES_CREDENTIALS_MISSING-none}"
    echo "$FIXTURE_FILE" > "$LOG/file-path"
  } > "$LOG/seen"
  EOF
  chmod +x "$fakes"/*

  failures=0
  fail() { echo "FAIL $1"; printf '%s\n' "$said" | sed 's/^/  said: /'; sed 's/^/  seen: /' "$log/seen" 2>/dev/null || true; failures=$((failures + 1)); }
  home() {
    rm -rf "$scratch" "$log" "$run" "$TMPDIR/fake"
    mkdir -p "$scratch" "$log" "$run" "$TMPDIR/fake"
    chmod 700 "$run"
    printf '%s\n' "$@" > "$TMPDIR/fake/keyring"
  }
  deliver() {
    said=$(cd "$scratch" && env -i HOME="$scratch" XDG_RUNTIME_DIR="$run" LOG="$log" FAKE="$TMPDIR/fake" SENTINEL="$sentinel" CONSUMER="$fakes/consumer" \
      PATH="$fakes:${pkgs.coreutils}/bin" "$@" 2>&1 < /dev/null) && status=0 || status=$?
    case $said in *"''${sentinel%%-*}"*) fail "$*: no value, nor any part of one, reaches the output" ;; esac
    if grep -qF "''${sentinel%%-*}" "$log/argv" 2>/dev/null; then fail "$*: no value is on a command line"; fi
    if grep -rqF "''${sentinel%%-*}" "$scratch" 2>/dev/null; then fail "$*: no value is left in the home"; fi
    [ -z "$(ls -A "$run")" ] || fail "$*: nothing is left in the runtime directory"
  }
  saw() { grep -qx -- "$1" "$log/seen" 2>/dev/null || fail "$2"; }

  home slack/user-token=xoxp slack/xoxc-token=xoxc slack/xoxd-token=xoxd
  deliver ${slack} --transport stdio
  [ "$status" = 0 ] || fail "slack-mcp runs the server with a user token, not exit $status"
  grep -qx 'npx -y slack-mcp-server@latest --transport stdio' "$log/argv" || fail "slack-mcp starts the server with its own arguments"
  saw "SLACK_MCP_XOXP_TOKEN xoxp" "slack-mcp hands the user token in SLACK_MCP_XOXP_TOKEN"
  saw "SLACK_MCP_XOXC_TOKEN unset" "with a user token, the browser token is not handed on"

  home slack/xoxc-token=xoxc slack/xoxd-token=xoxd
  deliver ${slack}
  [ "$status" = 0 ] || fail "slack-mcp runs the server with the browser pair, not exit $status"
  saw "SLACK_MCP_XOXP_TOKEN unset" "without a user token, none is handed on"
  saw "SLACK_MCP_XOXC_TOKEN xoxc" "the browser token is handed on"
  saw "SLACK_MCP_XOXD_TOKEN xoxd" "the browser cookie is handed on"

  home slack/xoxc-token=xoxc
  deliver ${slack}
  [ "$status" = 1 ] || fail "half the browser pair is not enough, so slack-mcp exits 1, not $status"
  [ ! -e "$log/seen" ] || fail "half the browser pair never starts the server"
  case $said in *"unavailable: slack/user-token slack/xoxd-token"*) ;; *) fail "slack-mcp names the credentials no tier holds" ;; esac
  case $said in *chars* | *prefix*) fail "slack-mcp prints no length or prefix of a token" ;; esac

  home slack/user-token=xoxc
  deliver ${slack}
  [ "$status" = 1 ] || fail "a user token of the wrong shape is refused, not exit $status"
  case $said in *"not shaped as that credential should be: slack/user-token"*) ;; *) fail "slack-mcp names a credential of the wrong shape without printing it" ;; esac

  home fixture/env=env fixture/file=file fixture/stdin=stdin
  deliver ${consumer} --flag
  [ "$status" = 0 ] || fail "the generated wrapper runs the consumer, not exit $status"
  saw "env delivered" "env delivery sets the declared variable"
  saw "file delivered 600 700" "file delivery hands a 0600 file in a 0700 directory"
  saw "stdin delivered" "stdin delivery pipes the value"
  saw "missing none" "nothing is reported missing when every tier answers"
  case $(cat "$log/file-path") in "$run"/*) ;; *) fail "the file is in the private runtime directory" ;; esac

  home fixture/file=file
  deliver ${consumer}
  saw "missing fixture/env fixture/stdin" "the consumer is told which credentials are unavailable, by name"
  ! grep -qx "env delivered" "$log/seen" || fail "an unavailable env credential leaves its variable unset"

  rm -rf "$log" && mkdir -p "$log"
  printf 'fixture/file=file\n' > "$TMPDIR/fake/keyring"
  said=$(env -i HOME="$scratch" LOG="$log" FAKE="$TMPDIR/fake" SENTINEL="$sentinel" PATH="$fakes:${pkgs.coreutils}/bin" ${credential} files "$run/svc" fixture/file fixture/env 2>&1) || fail "files exits 0 even when a credential is unavailable"
  [ "$(cat "$run/svc/fixture/file" 2>/dev/null)" = "file-$sentinel" ] && [ "$(stat -c %a "$run/svc/fixture/file")" = 600 ] && [ "$(stat -c %a "$run/svc")" = 700 ] \
    || fail "the service pre-start writes each credential as a 0600 file in a 0700 directory"
  [ ! -e "$run/svc/fixture/env" ] || fail "the pre-start writes no file for an unavailable credential"
  case $said in *"fixture/env is unavailable"*) ;; *) fail "the pre-start names the credential it could not write" ;; esac
  case $said in *"$sentinel"*) fail "the pre-start prints no value" ;; esac

  said='${builtins.toJSON unit}'
  case $said in *'"RuntimeDirectory":"dotfiles-credentials-fixture-service"'*'"RuntimeDirectoryMode":"0700"'*) ;; *) fail "a Linux service with credentials gets a private runtime directory that systemd removes" ;; esac
  case $said in *'"ExecStartPre":"'*'dotfiles-credential files %t/dotfiles-credentials-fixture-service fixture/file"'*) ;; *) fail "a Linux service with credentials writes them before it starts" ;; esac
  case $said in *'DOTFILES_CREDENTIALS_DIRECTORY=%t/dotfiles-credentials-fixture-service'*) ;; *) fail "a Linux service learns where its credential files are" ;; esac
  said='${builtins.toJSON agent}'
  case $said in *'DARWIN_USER_TEMP_DIR'*'dotfiles-credential files'*'fixture/file'*'DOTFILES_CREDENTIALS_DIRECTORY'*'"fixture"'*) ;; *) fail "a darwin service with credentials writes them into the per-user temp directory before it execs" ;; esac

  cat > "$fakes/source" <<'EOF'
  #!${pkgs.runtimeShell}
  printf '{"PROJECT_KEY": "project-%s", "PATH": "/evil", "not-a-name": "x", "NODE_AUTH_TOKEN": "project-%s"}\n' "$SENTINEL" "$SENTINEL"
  exec sleep 60
  EOF
  cat > "$fakes/gh" <<'EOF'
  #!${pkgs.runtimeShell}
  printf '%s\n' "gh $*" >> "$LOG/argv"
  [ "$*" = "auth token" ] && [ -e "$FAKE/gh-login" ] && printf 'derived-%s\n' "$SENTINEL"
  EOF
  cat > "$fakes/systemctl" <<'EOF'
  #!${pkgs.runtimeShell}
  printf '%s\n' "systemctl $*" >> "$LOG/argv"
  if [ "$2" = import-environment ]; then
    shift 2
    for k in "$@"; do eval "v=\''${$k-}"; case $v in *"$SENTINEL") echo "$k carried" ;; *) echo "$k empty" ;; esac; done >> "$LOG/imported"
  fi
  EOF
  chmod +x "$fakes"/*
  session() {
    rm -rf "$log" && mkdir -p "$log"
    said=$(cd "$scratch" && env -i HOME="$scratch" XDG_RUNTIME_DIR="$run" LOG="$log" FAKE="$TMPDIR/fake" SENTINEL="$sentinel" SOURCE="$1" DOTFILES_SESSION_INTERVAL=1 \
      PATH="$fakes:${pkgs.coreutils}/bin" ${pkgs.coreutils}/bin/timeout 4 ${pkgs.bash}/bin/bash -c "exec $2" 2>&1) && status=0 || status=$?
    envsh=$scratch/.config/dotfiles/env.sh
    case $said in *"$sentinel"*) fail "the session writer prints no value" ;; esac
    if grep -qF "$sentinel" "$log/argv" 2>/dev/null; then fail "the session writer puts no value on a command line"; fi
    for f in $(find "$scratch" -type f); do
      [ "$f" = "$envsh" ] || ! grep -qF "$sentinel" "$f" || fail "no value is in $f, outside the session file"
    done
  }
  has() { grep -qx -- "$1" "$envsh" 2>/dev/null || fail "$2"; }

  home
  touch "$TMPDIR/fake/gh-login"
  session "$fakes/source" ${writerArgs "stub-work-laptop"}
  [ "$status" = 124 ] || fail "the session writer keeps running, not exit $status"
  [ "$(stat -c %a "$envsh" 2>/dev/null)" = 600 ] && [ "$(stat -c %a "$(dirname "$envsh")")" = 700 ] || fail "the session file is 0600 in a 0700 directory"
  has "export PROJECT_KEY=project-$sentinel" "the provider's whole env project reaches the session file"
  has "export NODE_AUTH_TOKEN=derived-$sentinel" "a declared session credential is derived from gh's login and wins over the env project"
  has "__DOTFILES_KEYS='NODE_AUTH_TOKEN PROJECT_KEY'" "the key list names every exported key, and PATH and not-a-name are dropped"
  grep -qx 'systemctl --user import-environment NODE_AUTH_TOKEN PROJECT_KEY' "$log/argv" || fail "on a Linux desktop the keys reach the user session by name"
  [ "$(sort -u "$log/imported" 2>/dev/null)" = "$(printf '%s\n' 'NODE_AUTH_TOKEN carried' 'PROJECT_KEY carried')" ] || fail "systemctl import-environment finds each value in its own environment"

  home github/packages-token=stored
  touch "$TMPDIR/fake/gh-login"
  session - ${writerArgs "stub-work-laptop"}
  has "export NODE_AUTH_TOKEN=stored-$sentinel" "the local store comes before derive"
  ! grep -q '^gh' "$log/argv" || fail "with the token stored, gh is never asked"
  has "__DOTFILES_KEYS=NODE_AUTH_TOKEN" "without a provider env project, only declared credentials are exported"

  home
  session - ${writerArgs "stub-work-laptop"}
  has "__DOTFILES_KEYS='''" "with no tier holding the token and no env project, the session file exports nothing"
  case $said in *"unavailable: github/packages-token"*) ;; *) fail "the writer names a session credential no tier holds" ;; esac

  home
  touch "$TMPDIR/fake/gh-login"
  session "$fakes/source" ${writerArgs "stub-headless"}
  has "export NODE_AUTH_TOKEN=derived-$sentinel" "a headless machine derives the token too"
  ! grep -q '^systemctl' "$log/argv" 2>/dev/null || fail "a headless machine imports nothing into a user session"

  said=$(cat ${pkgs.writeText "bedrock-aliases" (builtins.toJSON (laptop.dotfiles.mutable.".config/bedrock-aliases.env" or null))})
  case $said in *'"mode":"0600"'*'"strategy":"overwrite"'*) ;; *) fail "the bedrock ARNs are rendered into a 0600 file" ;; esac
  case $said in *"BEDROCK_AIP_SONNET=arn:aws:bedrock:us-west-2:000000000000:application-inference-profile/example-sonnet\\n"*) ;; *) fail "each ARN from private.bedrock is one variable per line" ;; esac

  [ "$failures" = 0 ]
  touch $out
''

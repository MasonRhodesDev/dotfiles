{ lib, pkgs, stub }:
let
  config = name: stub.${name}.configuration.config;
  bin = name: file: (config name).home.file.".local/bin/${file}".source;
  project = name: (config name).home.file.".config/infisical/project.json".source or "";
  carried = name: pkgs.writeText "infisical-warnings-${name}" (config name).home.extraBuilderCommands;
  provider = (config "stub-work-laptop").dotfiles.credentialProvider.get;
  credential = "${(config "stub-work-laptop").dotfiles.credential}/bin/dotfiles-credential";
  conditions = name: pkgs.writeText "infisical-conditions-${name}" (lib.concatMapStrings
    (s: "${s} ${toString (config name).systemd.user.services.${s}.Unit.ConditionPathExists}\n")
    [ "secret-inbox" ]);

  api = pkgs.writeText "fake-infisical-api.py" ''
    import http.server, json, sys
    port, log, ready = int(sys.argv[1]), sys.argv[2], sys.argv[3]
    class H(http.server.BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass
        def do_POST(self):
            body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            if self.path == "/api/v1/auth/universal-auth/login":
                ok = body == {"clientId": "inbox-id", "clientSecret": "inbox-secret"}
                code, reply = (200, {"accessToken": "inbox-token"}) if ok else (401, {"message": "bad identity"})
            else:
                with open(log, "a") as f:
                    f.write(json.dumps({"path": self.path, "auth": self.headers.get("Authorization"), "body": body}, sort_keys=True) + "\n")
                code, reply = 200, {}
            self.send_response(code)
            self.end_headers()
            self.wfile.write(json.dumps(reply).encode())
    srv = http.server.HTTPServer(("127.0.0.1", port), H)
    open(ready, "w").close()
    srv.serve_forever()
  '';

  client = pkgs.writeText "inbox-client.py" ''
    import json, sys, urllib.request
    port, token = sys.argv[1], sys.argv[2]
    req = urllib.request.Request(f"http://127.0.0.1:{port}/api/requests", method="POST",
                                 data=json.dumps({"key": "FIXTURE_KEY", "note": "fixture"}).encode(),
                                 headers={"Content-Type": "application/json", "Authorization": "Bearer " + token})
    rid = json.loads(urllib.request.urlopen(req).read())["url"].rsplit("/", 1)[1]
    form = urllib.request.Request(f"http://127.0.0.1:{port}/r/{rid}", method="POST", data=b"value=fixture-value",
                                  headers={"Tailscale-User-Login": "fixture-owner"})
    print(urllib.request.urlopen(form).read().decode())
  '';
in
pkgs.runCommand "check-infisical-consumers" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  set -u
  secret=fixture-client-secret-9876543210
  fakes=$TMPDIR/fakes
  log=$TMPDIR/log
  scratch=$TMPDIR/scratch
  mkdir -p "$fakes"

  cat > "$fakes/infisical" <<'EOF'
  #!${pkgs.runtimeShell}
  echo "infisical $*" >> "$LOG/calls"
  for v in INFISICAL_PROJECT_ID INFISICAL_ENV INFISICAL_PATH; do [ -z "''${!v+x}" ] || echo "$v" >> "$LOG/leaked"; done
  case $1 in
    login)
      [ "''${INFISICAL_UNIVERSAL_AUTH_CLIENT_ID-}" = fixture-id ] && [ "''${INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET-}" = "$SECRET" ] || exit 1
      echo fixture-token ;;
    export)
      [ "''${INFISICAL_TOKEN-}" = fixture-token ] || exit 1
      echo '[{"key": "FIXTURE_KEY", "value": "fixture value"}]' ;;
    run)
      [ "''${INFISICAL_TOKEN-}" = fixture-token ] || exit 1
      printf '%s\n' "$@" > "$LOG/run" ;;
  esac
  EOF
  cat > "$fakes/tailscale" <<'EOF'
  #!${pkgs.runtimeShell}
  echo '{"Self": {"UserID": 1, "DNSName": "box.example.invalid."}, "User": {"1": {"LoginName": "fixture-owner"}}}'
  EOF
  cat > "$fakes/secret-tool" <<'EOF'
  #!${pkgs.runtimeShell}
  [ "$1" = lookup ] || exit 1
  while IFS='=' read -r name value; do [ "$name" != "$5" ] || { printf '%s' "$value"; exit 0; }; done < "$LOG/keyring"
  exit 1
  EOF
  chmod +x "$fakes"/*

  failures=0
  fail() { echo "FAIL $1"; echo "  said: $said"; sed 's/^/  call: /' "$log/calls" 2>/dev/null || true; failures=$((failures + 1)); }
  home() {
    rm -rf "$log" "$scratch"
    mkdir -p "$log" "$scratch/.config/infisical"
    [ -z "$1" ] || cp "$1" "$scratch/.config/infisical/project.json"
    case $2 in
      exported) printf '%s\n' "export INFISICAL_CLIENT_ID=fixture-id" "  export INFISICAL_CLIENT_SECRET='$secret'" > "$scratch/.config/infisical/machine.env" ;;
      no-secret) printf '%s\n' INFISICAL_CLIENT_ID=fixture-id "INFISICAL_CLIENT_SECRET=" > "$scratch/.config/infisical/machine.env" ;;
      no-id) printf '%s\n' "INFISICAL_CLIENT_ID=  " "INFISICAL_CLIENT_SECRET=$secret" > "$scratch/.config/infisical/machine.env" ;;
      yes) printf '%s\n' INFISICAL_PROJECT_ID=machine-env-project "INFISICAL_CLIENT_ID = 'fixture-id'" INFISICAL_ENV=machine-env-env "INFISICAL_CLIENT_SECRET=\"$secret\"" INFISICAL_PATH=/machine-env > "$scratch/.config/infisical/machine.env" ;;
    esac
    printf '%s\n' infisical/inbox-client-id=inbox-id infisical/inbox-client-secret=inbox-secret > "$log/keyring"
  }
  run() {
    local limit=$1; shift
    said=$(cd "$scratch" && HOME=$scratch LOG=$log SECRET=$secret PATH=$fakes:${pkgs.coreutils}/bin INFISICAL_SYNC_INTERVAL=1 \
      INBOX_PORT=18470 INFISICAL_API_URL=http://127.0.0.1:18471 \
      ${pkgs.coreutils}/bin/timeout "$limit" "$@" 2>&1) && status=0 || status=$?
  }
  untouched() {
    ! grep -q '^infisical' "$log/calls" 2>/dev/null || fail "$1: infisical never runs"
  }
  identity_only() {
    ! grep -q machine-env "$log/calls" 2>/dev/null || fail "$1: no project, environment or path from machine.env reaches infisical"
    [ ! -s "$log/leaked" ] || fail "$1: infisical's environment never carries $(tr '\n' ' ' < "$log/leaked")"
    ! grep -q -- "$secret" "$log/calls" 2>/dev/null || fail "$1: the client secret is never on a command line"
  }

  laptop=${project "stub-work-laptop"}
  desktop=${project "stub-gaming-desktop"}

  [ -n "$laptop" ] || { said=; fail "a machine with private.infisical gets project.json"; }
  [ -z "$desktop" ] || { said=; fail "a machine without private.infisical gets no project.json"; }

  for c in ${conditions "stub-work-laptop"} ${conditions "stub-gaming-desktop"}; do
    said=$(cat "$c")
    for unit in secret-inbox; do
      grep -q "^$unit .*%h/.config/infisical/machine.env" "$c" && grep -q "^$unit .*%h/.config/infisical/project.json" "$c" \
        || fail "$c: $unit starts only with machine.env and project.json"
    done
  done

  warned() {
    rm -rf "$TMPDIR/generation"
    mkdir -p "$TMPDIR/generation"
    (out=$TMPDIR/generation; . "$1")
    said=$(cat "$TMPDIR/generation/dotfiles-warnings" 2>/dev/null || true)
  }
  warned ${carried "stub-work-laptop"}
  [ -z "$said" ] || fail "a machine with an Infisical project carries no warning"
  warned ${carried "stub-gaming-desktop"}
  [ "$(wc -l <<< "$said")" = 1 ] && grep -q "^stub-gaming-desktop: .*private.infisical.projectId.*private.infisical.environment" <<< "$said" \
    || fail "a machine with Infisical secrets and no project carries one warning that names it and both keys"

  sync=${(config "stub-work-laptop").dotfiles.sessionSource}
  exec=${bin "stub-work-laptop" "infisical-exec"}
  inbox=${bin "stub-work-laptop" "secret-inbox"}

  home "$laptop" yes
  run 5 ${pkgs.bash}/bin/bash "$sync"
  grep -qx '{"FIXTURE_KEY": "fixture value"}' <<< "$said" || fail "the env project goes to the session env writer as one JSON line"
  [ -z "$(ls -A "$scratch/.config/infisical" | grep -v -e machine.env -e project.json)" ] || fail "the env project writes no file of its own"
  grep -q -- '^infisical export .*--projectId example-project --env example-env --path /example-path$' "$log/calls" || fail "env sync exports the rendered project, environment and path"
  identity_only "env sync"

  home "" yes
  run 10 ${pkgs.bash}/bin/bash "$sync"
  [ "$status" = 0 ] || fail "env sync without project.json exits cleanly, not $status"
  case $said in *"no Infisical project for this machine"*) ;; *) fail "env sync without project.json says why" ;; esac
  untouched "env sync without project.json"
  case $said in *"{"*) fail "env sync without project.json sends nothing" ;; esac

  home "$laptop" no
  run 10 ${pkgs.bash}/bin/bash "$sync"
  [ "$status" = 0 ] || fail "env sync without machine.env exits cleanly, not $status"
  case $said in *"not logged in to Infisical"*) ;; *) fail "env sync without machine.env says why" ;; esac
  untouched "env sync without machine.env"

  home "$laptop" yes
  run 10 ${pkgs.bash}/bin/bash "$exec" fixture-command --flag
  [ "$status" = 0 ] || fail "infisical-exec runs the command, not $status"
  [ "$(cat "$log/run" 2>/dev/null)" = "$(printf '%s\n' run --watch --silent --projectId=example-project --env=example-env --path=/example-path -- fixture-command --flag)" ] \
    || fail "infisical-exec runs the command with the rendered project, environment and path"
  identity_only "infisical-exec"

  home "" yes
  run 10 ${pkgs.bash}/bin/bash "$exec" fixture-command
  [ "$status" = 3 ] || fail "infisical-exec without project.json exits 3, not $status"
  case $said in *"no Infisical project for this machine"*) ;; *) fail "infisical-exec without project.json says why" ;; esac
  untouched "infisical-exec without project.json"

  home "$laptop" no
  run 10 ${pkgs.bash}/bin/bash "$exec" fixture-command
  [ "$status" = 3 ] || fail "infisical-exec without machine.env exits 3, not $status"
  case $said in *"not logged in to Infisical"*) ;; *) fail "infisical-exec without machine.env says why" ;; esac
  untouched "infisical-exec without machine.env"

  home "$laptop" exported
  run 10 ${pkgs.bash}/bin/bash "$exec" fixture-command
  [ "$status" = 0 ] && grep -q '^infisical login' "$log/calls" || fail "infisical-exec reads a machine.env whose lines start with export"

  for missing in no-secret no-id; do
    home "$laptop" $missing
    run 10 ${pkgs.bash}/bin/bash "$exec" fixture-command
    [ "$status" = 3 ] || fail "infisical-exec with an empty credential ($missing) exits 3, not $status"
    case $said in *"sets no INFISICAL_CLIENT_"*) ;; *) fail "infisical-exec with an empty credential ($missing) says which" ;; esac
    untouched "infisical-exec with an empty credential ($missing)"
    run 10 ${pkgs.bash}/bin/bash ${provider} tailscale/work/authkey
    [ "$status" != 0 ] || fail "the secret provider with an empty credential ($missing) exits non-zero, so its consumer falls back"
    untouched "the secret provider with an empty credential ($missing)"
  done

  home "$laptop" yes
  python3 ${api} 18471 "$log/api" "$log/api-ready" &
  server=$!
  for _ in $(seq 100); do [ -e "$log/api-ready" ] && break; sleep 0.1; done
  creds=$TMPDIR/run/dotfiles-credentials-secret-inbox
  HOME=$scratch LOG=$log PATH=$fakes:${pkgs.coreutils}/bin ${credential} files "$creds" infisical/inbox-client-id infisical/inbox-client-secret 2> "$log/prestart"
  [ "$(stat -c %a "$creds/infisical/inbox-client-secret" 2>/dev/null)" = 600 ] || { said=$(cat "$log/prestart"); fail "the inbox's pre-start writes its identity from the local store as 0600 files"; }
  (cd "$scratch" && HOME=$scratch PATH=$fakes:${pkgs.coreutils}/bin INBOX_PORT=18470 INFISICAL_API_URL=http://127.0.0.1:18471 DOTFILES_CREDENTIALS_DIRECTORY=$creds \
    exec ${pkgs.python3}/bin/python3 "$inbox" 2> "$log/inbox") &
  inboxpid=$!
  for _ in $(seq 100); do [ -s "$scratch/.config/infisical/inbox.token" ] && break; sleep 0.1; done
  said=$(python3 ${client} 18470 "$(cat "$scratch/.config/infisical/inbox.token" 2>/dev/null)" 2>&1) || true
  kill "$inboxpid" "$server" 2>/dev/null || true
  wait 2>/dev/null || true
  case $said in *"saved to Infisical"*) ;; *) fail "the inbox saves a secret" ;; esac
  want='{"auth": "Bearer inbox-token", "body": {"environment": "example-env", "projectId": "example-project", "secretPath": "/example-path", "secretValue": "fixture-value"}, "path": "/api/v4/secrets/FIXTURE_KEY"}'
  [ "$(cat "$log/api" 2>/dev/null)" = "$want" ] || { said=$(cat "$log/api" "$log/inbox" 2>&1 || true); fail "the inbox writes to the rendered project, environment and path"; }

  home "$laptop" yes
  run 10 ${pkgs.python3}/bin/python3 "$inbox"
  [ "$status" = 0 ] || fail "the inbox without its identity exits cleanly, not $status"
  case $said in *"no inbox identity"*"dotfiles-credential set infisical/inbox-client-id"*) ;; *) fail "the inbox without its identity says how to add it" ;; esac
  [ ! -e "$scratch/.config/infisical/inbox.token" ] || fail "the inbox without its identity never listens"

  home "" yes
  run 10 ${pkgs.python3}/bin/python3 "$inbox"
  [ "$status" = 0 ] || fail "the inbox without project.json exits cleanly, not $status"
  case $said in *"no Infisical project for this machine"*) ;; *) fail "the inbox without project.json says why" ;; esac
  [ ! -e "$scratch/.config/infisical/inbox.token" ] || fail "the inbox without project.json never listens"

  home "$laptop" no
  run 10 ${pkgs.python3}/bin/python3 "$inbox"
  [ "$status" = 0 ] || fail "the inbox without machine.env exits cleanly, not $status"
  case $said in *"machine.env is missing"*) ;; *) fail "the inbox without machine.env says why" ;; esac
  [ ! -e "$scratch/.config/infisical/inbox.token" ] || fail "the inbox without machine.env never listens"

  [ "$failures" = 0 ]
  touch $out
''

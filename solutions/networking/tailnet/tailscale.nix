let
  join = pkgs: pkgs.writeShellScript "tailscale-join" ''
    profile=$1 secret=$2 fetch=$3 tailnet=$4 as=''${5-}
    jq=${pkgs.jq}/bin/jq

    step() {
      local id
      id=$(tailscale switch --list --json 2>/dev/null \
        | $jq -r --arg p "$profile" --arg t "$tailnet" 'first(.[] | select((.selected | not) and (.nickname == $p or ($t != "" and .tailnet == $t))) | .id) // empty' 2>/dev/null)
      if [ -n "$id" ]; then echo "''${as}tailscale switch $id"; else echo "''${as}tailscale login --nickname=$profile"; fi
    }

    manual() {
      echo "tailscale: $1. To join the $profile tailnet by hand, run: $(step)"
      exit 0
    }

    command -v tailscale >/dev/null 2>&1 || manual "the tailscale CLI is not installed"
    status=$(tailscale status --json 2>/dev/null)
    state=$($jq -r '.BackendState // empty' <<< "$status" 2>/dev/null)
    case $state in
      NeedsLogin | NoState) ;;
      "") manual "tailscaled is not answering" ;;
      *)
        current=$($jq -r '.CurrentTailnet.Name // empty' <<< "$status" 2>/dev/null)
        if [ -n "$tailnet" ] && [ -n "$current" ] && [ "$current" != "$tailnet" ]; then
          echo "tailscale: this machine is logged in to the tailnet $current, not the $profile tailnet $tailnet. Left as it is. To move it, run: $(step)"
        fi
        exit 0 ;;
    esac

    dir=$(mktemp -d "''${XDG_RUNTIME_DIR:-''${TMPDIR:-/tmp}}/tailscale-join.XXXXXX") || manual "there is no private directory for the auth key"
    trap 'rm -rf "$dir"' EXIT
    if ! (umask 077 && "$fetch" "$secret" > "$dir/key" 2> "$dir/why") || [ ! -s "$dir/key" ]; then
      manual "the $profile auth key is unavailable: $(head -n 1 "$dir/why")"
    fi
    if tailscale login --auth-key="file:$dir/key" --nickname="$profile" --timeout=60s > "$dir/said" 2>&1; then
      rm -f "$dir/key"
      echo "tailscale: joined the $profile tailnet"
    else
      rm -f "$dir/key"
      manual "login with the $profile auth key failed: $(tail -n 1 "$dir/said")"
    fi
    exit 0
  '';

  rootJoin = { pkgs, lib, user, userPath, profile, secret, fetch, tailnet, tailscale }:
    let
      keyAsUser = pkgs.writeShellScript "tailscale-key-as-user" ''exec sudo -u ${user} -H ${pkgs.coreutils}/bin/env PATH=${lib.concatStringsSep ":" userPath}:/usr/bin:/bin ${fetch} "$@"'';
    in
    ''
      PATH=${tailscale}/bin:${pkgs.coreutils}/bin:/usr/bin:/bin:/usr/sbin:/sbin ${join pkgs} ${profile} ${secret} ${keyAsUser} ${lib.escapeShellArg tailnet} "sudo "
    '';

  keyOf = pkgs: credential: pkgs.writeShellScript "tailscale-key" ''exec ${credential}/bin/dotfiles-credential get "$1"'';

  userJoin = { config, lib, pkgs, machine, identity, ... }:
    let inherit (machine.traits) profile; in
    {
      home.activation.tailscaleJoin = lib.hm.dag.entryAfter [ "installPackages" "linkGeneration" ] ''
        if [[ ! -v DRY_RUN ]]; then
          PATH=$PATH:${config.home.profileDirectory}/bin:/usr/local/bin:/usr/bin \
            ${join pkgs} ${profile} tailscale/${profile}/authkey ${keyOf pkgs config.dotfiles.credential} ${lib.escapeShellArg (identity.tailnets.${profile} or "")}
        fi
      '';
    };

  root = { machine, ... }: {
    packages = {
      arch = [ "tailscale" ];
      fedora = [ "tailscale" ];
    };
    units = [ "tailscaled.service" ];
    script = ''
      if ! tailscale set --operator=${machine.user.name}; then
        echo "  could not make ${machine.user.name} the tailscale operator; activation then cannot log in, so run: sudo tailscale set --operator=${machine.user.name}"
        exit 1
      fi
    '';
  };
in
{
  name = "Tailscale";
  description = "tailscaled on every machine, joined to the tailnet of the machine's profile with that profile's auth key from the machine's credential chain. Without the key, activation prints the manual login and goes on. A machine already logged in to a tailnet other than the one the identity names for its profile gets a warning with the switch, never a switch. Linux: distro package and unit, the user as operator. darwin: the Tailscale app with a GUI, and the open-source tailscaled as a launchd daemon on a headless Mac.";
  platforms = [ "linux" "darwin" ];

  home = { lib, machine, ... }:
    let inherit (machine.traits) profile; in
    {
      dotfiles.fragments."bash/completions" = lib.mkIf (lib.elem "bash" machine.enabled) "gen tailscale tailscale completion bash\n";

      dotfiles.credentials."tailscale/${profile}/authkey" = {
        description = "Tailscale auth key that joins a machine to the ${profile} tailnet. Reusable, since every ${profile} machine uses it.";
        to = "tailscale join (activation)";
        deliver.file = true;
      };
    };

  linux.home = userJoin;

  darwin.home = { lib, pkgs, machine, ... }@args: lib.mkIf (!machine.traits.headless) (lib.mkMerge [
    (userJoin args)
    {
      home.packages = [
        (pkgs.writeShellScriptBin "tailscale" ''exec /Applications/Tailscale.app/Contents/MacOS/Tailscale "$@"'')
      ];
    }
  ]);

  linux.root = root;

  checks = { pkgs, lib, evalHome, ... }:
    let
      program = (evalHome { modules = [{ dotfiles.root.tailscale = root { machine.user.name = "fixture"; }; }]; }).config.dotfiles.rootApplyScratch;
      fakes = pkgs.runCommand "tailscale-root-fakes" { } ''
        mkdir -p $out/bin
        cat > $out/bin/tailscale <<'EOF'
        #!${pkgs.runtimeShell}
        echo "tailscale $*" >> "$LOG/calls"
        case $1 in
          status) [ "$TS_STATE" = down ] && exit 1; echo "{\"BackendState\": \"$TS_STATE\"}" ;;
          switch) echo '[]' ;;
          login) for a in "$@"; do case $a in --auth-key=file:*) cat "''${a#--auth-key=file:}" > "$LOG/key" ;; esac; done ;;
        esac
        EOF
        cat > $out/bin/sudo <<'EOF'
        #!${pkgs.runtimeShell}
        echo "sudo $*" >> "$LOG/calls"
        [ "$1" = -u ] && [ "$3" = -H ] || exit 1
        shift 3
        HOME=$LOG/user-home exec "$@"
        EOF
        chmod +x $out/bin/*
      '';
      userTools = pkgs.writeShellScriptBin "fixture-provider-cli" "true";
      fetch = pkgs.writeShellScript "fake-fetch" ''
        [ "$HOME" = "$LOG/user-home" ] || { echo "not the user's home" >&2; exit 1; }
        command -v fixture-provider-cli > /dev/null || { echo "the provider CLI is not installed" >&2; exit 1; }
        [ "$FETCH" = ok ] || { echo "the provider is offline" >&2; exit 1; }
        echo fixture-root-key
      '';
      step = pkgs.writeText "tailscale-root-join" (rootJoin {
        inherit pkgs lib fetch;
        user = "fixture";
        userPath = [ "${userTools}/bin" ];
        profile = "work";
        secret = "tailscale/work/authkey";
        tailnet = "";
        tailscale = fakes;
      });
    in
    {
      tailscale-root-join = pkgs.runCommand "tailscale-root-join" { } ''
        export LOG=$TMPDIR/log
        failures=0
        fail() { echo "FAIL $1"; echo "$said" | sed 's/^/  said: /'; failures=$((failures + 1)); }
        run() { rm -rf "$LOG"; mkdir -p "$LOG"; said=$(TS_STATE=$1 FETCH=$2 ${pkgs.bash}/bin/bash -eu ${step} 2>&1) || fail "$1 $2: the join never fails the activation"; }

        run NeedsLogin ok
        grep -qx "sudo -u fixture -H .*/env PATH=${userTools}/bin:.* .*-fake-fetch tailscale/work/authkey" "$LOG/calls" || fail "the key is fetched as the user, with the user's tools on PATH"
        [ "$(cat "$LOG/key" 2>/dev/null)" = fixture-root-key ] || fail "root logs in with the user's key"
        case $said in *"joined the work tailnet"*) ;; *) fail "the join is reported" ;; esac

        run NeedsLogin offline
        case $said in *"the work auth key is unavailable: the provider is offline"*"To join the work tailnet by hand, run: sudo tailscale login --nickname=work"*) ;; *) fail "without the key, the manual login is printed for root" ;; esac
        ! grep -q '^tailscale login' "$LOG/calls" || fail "without the key, no login is attempted"

        run down ok
        case $said in *"tailscaled is not answering"*"run: sudo tailscale login --nickname=work"*) ;; *) fail "with tailscaled down, the manual login is printed for root" ;; esac

        run Running ok
        [ -z "$said" ] || fail "a joined machine is left alone, quietly"
        ! grep -q '^sudo' "$LOG/calls" || fail "a joined machine fetches no key"

        [ "$failures" = 0 ]
        touch $out
      '';

      tailscale-operator = pkgs.runCommand "tailscale-operator" { } ''
        export DOTFILES_ROOT_PREFIX=$TMPDIR/root FAKE=$TMPDIR/fake
        mkdir -p "$DOTFILES_ROOT_PREFIX/etc" "$FAKE/bin"
        echo ID=arch > "$DOTFILES_ROOT_PREFIX/etc/os-release"
        printf '#!/bin/sh\nexit 0\n' > "$FAKE/bin/pacman"
        printf '#!/bin/sh\nexit 0\n' > "$FAKE/bin/systemctl"
        printf '#!/bin/sh\necho "tailscale $*" >> "$FAKE/calls"\n[ ! -e "$FAKE/refuses" ]\n' > "$FAKE/bin/tailscale"
        chmod +x "$FAKE/bin"/*
        export PATH=$FAKE/bin:$PATH
        recorded() { readlink "$DOTFILES_ROOT_PREFIX/var/lib/dotfiles/applied" 2>/dev/null || true; }
        failures=0
        fail() { echo "FAIL $1: $said"; failures=$((failures + 1)); }

        touch "$FAKE/refuses"
        if said=$(${program}/bin/dotfiles-root-apply 2>&1); then fail "a refused operator makes the root program exit 1"; fi
        [ -z "$(recorded)" ] || fail "a refused operator leaves the root program unrecorded, so the next switch runs it again"
        case $said in *"sudo tailscale set --operator=fixture"*) ;; *) fail "a refused operator says what to run" ;; esac
        rm "$FAKE/refuses"
        said=$(${program}/bin/dotfiles-root-apply 2>&1) || fail "the next run, when the operator is set, exits 0"
        [ "$(grep -c -- '--operator=fixture' "$FAKE/calls")" = 2 ] || fail "the next run sets the operator again"
        [ -n "$(recorded)" ] || fail "the run that set the operator records itself"

        [ "$failures" = 0 ]
        touch $out
      '';
    };

  darwin.system = { config, lib, pkgs, machine, identity, ... }:
    let inherit (machine.traits) profile; in
    if machine.traits.headless then {
      services.tailscale.enable = true;
      system.activationScripts.postActivation.text = lib.mkAfter (rootJoin {
        inherit pkgs lib profile;
        user = machine.user.name;
        userPath = [ "${config.home-manager.users.${machine.user.name}.home.profileDirectory}/bin" "/opt/homebrew/bin" "/usr/local/bin" ];
        secret = "tailscale/${profile}/authkey";
        fetch = keyOf pkgs config.home-manager.users.${machine.user.name}.dotfiles.credential;
        tailnet = identity.tailnets.${profile} or "";
        tailscale = config.services.tailscale.package;
      });
    }
    else { homebrew.casks = [ "tailscale-app" ]; };
}

let
  scripts = { pkgs, lib, root }:
    lib.genAttrs [ "cargo" "eph-build-sweep" "claude-build-guard" ] (name: pkgs.writeScript name (builtins.replaceStrings
      [ "@ephRoot@" "@sharedTarget@" "@jq@" ]
      [ root "${dirOf root}/cargo-target" "${pkgs.jq}" ]
      (builtins.readFile ./${name})));
  guardHook = command: { matcher = "Bash"; hooks = [{ type = "command"; inherit command; }]; };
in
{
  name = "Build offload";
  description = "Where the machine entry names an ephemeral build root (private.ephBuildRoot): a cargo shim that gives each workspace its own target dir there, a timer that sweeps idle ones, and where Claude Code is, a hook that refuses build output aimed at the home disk.";
  platforms = [ "linux" ];
  requires = [ "rust" ];

  linux.home = { config, lib, pkgs, machine, ... }:
    let
      root = machine.private.ephBuildRoot;
      script = scripts { inherit pkgs lib root; };
      home = config.home.homeDirectory;
      has = id: lib.elem id machine.enabled;
    in
    lib.mkIf (machine.private ? ephBuildRoot) (lib.mkMerge [
      {
        home.file.".local/bin/cargo".source = script.cargo;
        home.file.".local/bin/eph-build-sweep".source = script.eph-build-sweep;
        systemd.user.services.eph-build-sweep = {
          Unit = {
            Description = "Delete idle per-workspace cargo target dirs under ${root}";
            ConditionPathIsDirectory = root;
          };
          Service = {
            Type = "oneshot";
            ExecStart = "%h/.local/bin/eph-build-sweep";
            Nice = 19;
          };
        };
        systemd.user.timers.eph-build-sweep = {
          Unit.Description = "Sweep idle cargo target dirs under ${root} every 15 minutes";
          Timer = {
            OnBootSec = "5min";
            OnUnitActiveSec = "15min";
          };
          Install.WantedBy = [ "timers.target" ];
        };
      }
      (lib.mkIf (has "claude-code") {
        home.file.".local/bin/claude-build-guard".source = script.claude-build-guard;
        dotfiles.mutable.".claude/settings.json" = {
          strategy = "merge-json";
          json.hooks.PreToolUse = [ (guardHook "${home}/.local/bin/claude-build-guard") ];
          adopt.hooks.PreToolUse = [ (guardHook "$HOME/.local/bin/claude-build-guard") ];
        };
      })
    ]);

  checks = { pkgs, lib, ... }:
    let script = scripts { inherit pkgs lib; root = "/fixture/eph"; }; in
    {
      build-offload = pkgs.runCommand "build-offload" { nativeBuildInputs = [ pkgs.util-linux pkgs.jq ]; } ''
        export HOME=$TMPDIR/home EPH_BUILD_ROOT=$TMPDIR/scratch/eph FAKE=$TMPDIR/fake
        mkdir -p "$HOME/ws/src" "$FAKE/bin" "$TMPDIR/scratch"
        touch "$HOME/ws/Cargo.toml"
        cat > "$FAKE/bin/cargo" <<'EOF'
        #!${pkgs.runtimeShell}
        if [ "$1" = locate-project ]; then echo "$PWD/Cargo.toml"; exit 0; fi
        echo "target=''${CARGO_TARGET_DIR:-unset} args=$*"
        EOF
        chmod +x "$FAKE/bin/cargo"
        export PATH=$FAKE/bin:$PATH
        cd "$HOME/ws"
        failures=0
        fail() { echo "FAIL $1"; echo "  said: $said"; failures=$((failures + 1)); }
        shim() { said=$(bash ${script.cargo} "$@" 2>&1); }
        guard() { jq -n --arg c "$1" '{tool_input: {command: $c}}' | bash ${script.claude-build-guard}; }

        shim build
        case $said in "target=$EPH_BUILD_ROOT/ws-"*" args=build") ;; *) fail "a workspace builds in its own dir under the build root" ;; esac
        dir=''${said#target=}; dir=''${dir%% *}
        [ -e "$dir/.eph-stamp" ] || fail "the build stamps its dir for the sweeper"
        CARGO_TARGET_DIR=/fixture/cargo-target shim build
        case $said in "target=$dir args=build") ;; *) fail "the shared target dir beside the build root is replaced by the workspace's own" ;; esac
        CARGO_TARGET_DIR=$HOME/.cache/target shim build
        case $said in *"is on the home disk or tmpfs; building in $dir instead"*"target=$dir args=build") ;; *) fail "a target dir in the home is moved to the build root, with a warning" ;; esac
        CARGO_TARGET_DIR=/elsewhere shim build
        [ "$said" = "target=/elsewhere args=build" ] || fail "a target dir outside the home is left alone"
        shim build --target-dir /x
        [ "$said" = "target=unset args=build --target-dir /x" ] || fail "an explicit --target-dir is left alone"
        EPH_BUILD_ROOT=/nowhere/eph shim build
        [ "$said" = "target=unset args=build" ] || fail "a machine without the build root's parent passes through"

        mkdir -p "$EPH_BUILD_ROOT/old" "$EPH_BUILD_ROOT/held"
        touch -d '5 hours ago' "$EPH_BUILD_ROOT/old/.eph-stamp" "$EPH_BUILD_ROOT/held/.eph-stamp"
        touch "$EPH_BUILD_ROOT/held/.eph-lock"
        flock -s "$EPH_BUILD_ROOT/held/.eph-lock" sleep 30 &
        sleep 1
        said=$(bash ${script.eph-build-sweep})
        [ ! -e "$EPH_BUILD_ROOT/old" ] || fail "the sweep removes a dir idle past its age"
        [ -e "$EPH_BUILD_ROOT/held" ] || fail "the sweep leaves a dir whose lock is held"
        [ -e "$dir" ] || fail "the sweep leaves a dir built in just now"
        kill %1 2>/dev/null || true

        said=$(guard 'CARGO_TARGET_DIR=~/.cache/t cargo build')
        [ "$(jq -r .hookSpecificOutput.permissionDecision <<< "$said")" = deny ] || fail "the guard refuses a target dir in the home"
        case $(jq -r .hookSpecificOutput.permissionDecisionReason <<< "$said") in *"under /fixture/eph/."*) ;; *) fail "the guard names the build root" ;; esac
        said=$(guard 'cargo build --target-dir /tmp/t')
        [ -n "$said" ] || fail "the guard refuses a target dir in /tmp"
        said=$(guard 'cargo build')
        [ -z "$said" ] || fail "the guard lets a plain build through"

        [ "$failures" = 0 ]
        touch $out
      '';
    };
}

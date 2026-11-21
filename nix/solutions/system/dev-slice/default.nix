let
  shim = pkgs: pkgs.writeShellScript "rust-analyzer" ''
    if [ -n "''${XDG_RUNTIME_DIR-}" ] && [ -S "$XDG_RUNTIME_DIR/bus" ]; then
      exec systemd-run --user --quiet --scope --slice=dev.slice --collect -- ${pkgs.rustup}/bin/rust-analyzer "$@"
    fi
    exec ${pkgs.rustup}/bin/rust-analyzer "$@"
  '';
in
{
  name = "dev.slice";
  description = "Deprioritised, memory-capped slice for builds, agents and LSPs; dev wrapper, a claude wrapper where Claude Code is, and a rust-analyzer shim that runs inside it where rust is.";
  platforms = [ "linux" ];
  when.uses = "dev";

  linux.home = { pkgs, lib, machine, ... }: {
    systemd.user.slices.dev = {
      Unit.Description = "Deprioritized development workloads (builds, agents, LSPs)";
      Slice = {
        CPUWeight = 20;
        IOWeight = 20;
        MemoryHigh = "16G";
        MemoryMax = "20G";
        MemorySwapMax = "8G";
        ManagedOOMMemoryPressure = "kill";
        ManagedOOMMemoryPressureLimit = "80%";
      };
    };

    home.file.".bashrc.d/dev-slice.bashrc" = lib.mkIf (lib.elem "bash" machine.enabled) {
      text = builtins.readFile ./dev-slice.bashrc
        + lib.optionalString (lib.elem "claude-code" machine.enabled) "\n${builtins.readFile ./dev-slice-claude.bashrc}";
    };

    home.file.".local/bin/rust-analyzer" = lib.mkIf (lib.elem "rust" machine.enabled) { source = shim pkgs; };
  };

  checks = { pkgs, ... }:
    let
      rustup = pkgs.writeShellScriptBin "rust-analyzer" ''
        echo "rust-analyzer $*"
      '';
    in
    {
      dev-slice-without-bus = pkgs.runCommand "dev-slice-without-bus" { nativeBuildInputs = [ pkgs.python3 ]; } ''
        mkdir -p fakes run
        cat > fakes/systemd-run <<'EOF'
        #!${pkgs.runtimeShell}
        echo "systemd-run $*" >> "$TMPDIR/calls"
        while [ "$1" != -- ]; do shift; done
        shift
        exec "$@"
        EOF
        chmod +x fakes/systemd-run
        export PATH=$PWD/fakes:$PATH
        failures=0
        fail() { echo "FAIL $1: $said"; failures=$((failures + 1)); }
        calls() { cat "$TMPDIR/calls" 2>/dev/null | wc -l; }
        shim=${shim (pkgs // { inherit rustup; })}

        said=$(env -u XDG_RUNTIME_DIR ${pkgs.bash}/bin/bash -c "source ${./dev-slice.bashrc}; dev echo ran" 2>&1) || fail "dev without a runtime directory runs the command"
        [ "$said" = ran ] && [ "$(calls)" = 0 ] || fail "dev without a runtime directory runs the command directly"
        said=$(XDG_RUNTIME_DIR=$PWD/run ${pkgs.bash}/bin/bash -c "source ${./dev-slice.bashrc}; dev echo ran" 2>&1) || fail "dev without a user bus runs the command"
        [ "$said" = ran ] && [ "$(calls)" = 0 ] || fail "dev without a user bus runs the command directly"
        said=$(env -u XDG_RUNTIME_DIR $shim --version 2>&1) || fail "the rust-analyzer shim without a user bus runs rust-analyzer"
        [ "$said" = "rust-analyzer --version" ] && [ "$(calls)" = 0 ] || fail "the rust-analyzer shim without a user bus runs rust-analyzer directly"

        python3 -c 'import socket, sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' run/bus
        said=$(XDG_RUNTIME_DIR=$PWD/run ${pkgs.bash}/bin/bash -c "source ${./dev-slice.bashrc}; dev echo ran" 2>&1) || fail "dev with a user bus runs the command"
        [ "$said" = ran ] && [ "$(calls)" = 1 ] || fail "dev with a user bus runs the command in dev.slice"
        said=$(XDG_RUNTIME_DIR=$PWD/run $shim --version 2>&1) || fail "the rust-analyzer shim with a user bus runs rust-analyzer"
        [ "$said" = "rust-analyzer --version" ] && [ "$(calls)" = 2 ] || fail "the rust-analyzer shim with a user bus runs it in dev.slice"

        [ "$failures" = 0 ]
        touch $out
      '';
    };

  inventory = {
    files = [ ".config/systemd/user/dev.slice" ".bashrc.d/dev-slice.bashrc" ".local/bin/rust-analyzer" ];
  };
}

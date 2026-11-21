{
  name = "Rust";
  description = "rustup with a default stable toolchain, cargo-deny, and the weekly prune of stale target dirs.";
  platforms = [ "linux" "darwin" ];

  home = { pkgs, lib, machine, ... }: {
    dotfiles.fragments."bash/completions" = lib.mkIf (lib.elem "bash" machine.enabled) "gen rustup    rustup completions bash\ngen cargo     rustup completions bash cargo\n";
    home.packages = [ pkgs.rustup pkgs.cargo-deny ];
    home.activation.rustupDefault = lib.hm.dag.entryAfter [ "installPackages" ] ''
      if ! ${pkgs.rustup}/bin/rustup show active-toolchain > /dev/null 2>&1; then
        { run ${pkgs.rustup}/bin/rustup default stable && run ${pkgs.rustup}/bin/rustup component add rust-analyzer; } \
          || warnEcho "rustup could not install a default toolchain. Run: rustup default stable && rustup component add rust-analyzer"
      fi
    '';
    home.file.".bashrc.d/rust.bashrc" = lib.mkIf (lib.elem "bash" machine.enabled) { source = ./rust.bashrc; };
    home.file.".local/bin/prune-cargo-targets" = { source = ./prune-cargo-targets; executable = true; };
  };

  linux.home = { ... }: {
    systemd.user.services.prune-cargo-targets = {
      Unit = {
        Description = "Reclaim Rust build caches nothing is using";
        Documentation = "man:cargo(1)";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "%h/.local/bin/prune-cargo-targets";
        Nice = 19;
        IOSchedulingClass = "idle";
      };
    };
    systemd.user.timers.prune-cargo-targets = {
      Unit.Description = "Weekly sweep of unused Rust build caches";
      Timer = {
        OnCalendar = "Sun *-*-* 04:00:00";
        Persistent = true;
        RandomizedDelaySec = 1800;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };

  inventory = {
    starts = {
      linux = [ "prune-cargo-targets.timer" ];
    };
    files = [
      ".config/systemd/user/prune-cargo-targets.service"
      ".config/systemd/user/prune-cargo-targets.timer"
      ".local/bin/prune-cargo-targets"
      ".bashrc.d/rust.bashrc"
    ];
    packages = {
      linux = [ "rustup" "cargo-deny" ];
      darwin = [ "rustup" "cargo-deny" ];
    };
  };
}

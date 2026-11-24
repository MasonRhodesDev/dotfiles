let
  protectedRepos = config: lib:
    lib.unique (lib.concatMap (step: lib.attrNames step.repositories.arch) (lib.attrValues config.dotfiles.root));

  guard = pkgs: repos: pkgs.writeShellApplication {
    name = "dotfiles-lib-guard";
    runtimeInputs = [ pkgs.binutils-unwrapped pkgs.libarchive pkgs.gawk pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.gnused ];
    text = ''
      repos=(${pkgs.lib.escapeShellArgs repos})
      resolver=${./resolve.awk}
    '' + builtins.readFile ./lib-guard.sh;
  };

  hook = pkgs: repos: ''
    [Trigger]
    Operation = Remove
    Type = Path
    Target = usr/lib/*.so*
    Target = usr/lib32/*.so*

    [Trigger]
    Operation = Upgrade
    Type = Package
    Target = *

    [Action]
    Description = Checking that no foreign package loses a shared library it loads...
    When = PreTransaction
    Exec = /bin/sh -c 'guard=${guard pkgs repos}/bin/dotfiles-lib-guard; if [ -x "$guard" ]; then exec "$guard" hook; fi; cat > /dev/null; echo "dotfiles-lib-guard: $guard is gone, so no library check ran. Run dot switch to put it back."'
    NeedsTargets
    AbortOnFail
  '';

  root = { config, lib, pkgs, ... }: {
    distros = [ "arch" ];
    files."/etc/pacman.d/hooks/00-dotfiles-lib-guard.hook".text = hook pkgs (protectedRepos config lib);
  };
in
{
  name = "Library guard";
  description = "Arch: a pacman hook that stops a transaction taking away a shared library that a foreign package, or one from a repository a solution adds, still loads, and a scan dot runs for libraries such packages already cannot load.";
  platforms = [ "linux" ];

  linux.root = root;

  linux.home = { config, lib, pkgs, ... }: {
    home.file.".local/share/dotfiles/unresolved-libraries" = {
      executable = true;
      source = pkgs.writeShellScript "unresolved-libraries" ''
        exec ${guard pkgs (protectedRepos config lib)}/bin/dotfiles-lib-guard unresolved
      '';
    };
  };

  checks = { pkgs, evalHome }: {
    lib-guard = import ./check.nix { inherit pkgs evalHome root; };
  };
}

{ dot, evalHome }:
let
  inherit (dot) lib;
  inherit (dot.loadCatalog (import ./fixtures/traits.nix) ./fixtures/catalog) fragmentOwners;

  refusedOn = enabled: module:
    let
      home = evalHome {
        modules = [ (lib.setDefaultModuleLocation "fixture#home" module) ];
        owners."fixture#home" = "fixture";
        inherit enabled fragmentOwners;
      };
    in
    map (a: a.message) (lib.filter (a: !a.assertion) home.config.assertions);
  refused = refusedOn [ ];

  lmtt = "lmtt writes theme files through symlinks, so a store link fails with EROFS. Declare it with dotfiles.mutable, or leave it unmanaged.";
  sharedWhy = "lmtt, hyprstate, Claude Code, infisical-sync and installers add files to it at runtime, so it cannot be one read-only store link";
  sharedFix = "Link the files inside it one by one (recursive = true), or declare them with dotfiles.mutable.";

  cases = {
    "an lmtt sibling cannot be a store link" = {
      got = refused { xdg.configFile."kitty/lmtt-colors.conf".text = "x"; };
      want = [ "~/.config/kitty/lmtt-colors.conf is declared as a store link by fixture, but ${lmtt}" ];
    };
    "a file lmtt setup injects into cannot be a store link" = {
      got = refused { home.file.".tmux.conf".text = "x"; };
      want = [ "~/.tmux.conf is declared as a store link by fixture, but ${lmtt}" ];
    };
    "a directory programs write into cannot be one store link" = {
      got = refused { xdg.configFile."nvim".source = ./fixtures/home-dir; };
      want = [ "~/.config/nvim is declared as one store link by fixture, but ${sharedWhy}. ${sharedFix}" ];
    };
    "the same directory linked file by file is fine" = {
      got = refused { xdg.configFile."nvim" = { source = ./fixtures/home-dir; recursive = true; }; };
      want = [ ];
    };
    "an app-rewritten file cannot be a store link" = {
      got = refused { xdg.configFile."zed/settings.json".text = "{}"; };
      want = [ "~/.config/zed/settings.json is declared as a store link by fixture, but the app rewrites its own config and replaces the link or fails to write. Declare it with dotfiles.mutable (merge-json when the app keeps keys of its own), or leave it unmanaged." ];
    };
    "an app-rewritten file is fine through dotfiles.mutable" = {
      got = refused { dotfiles.mutable.".config/karabiner/karabiner.json" = { strategy = "overwrite"; text = "{}"; }; };
      want = [ ];
    };
    "a runtime secret cannot be a store link" = {
      got = refused { home.file.".config/infisical/machine.env".text = "TOKEN=x"; };
      want = [ "~/.config/infisical/machine.env is declared as a store link by fixture, but it holds secrets that infisical-sync fetches at runtime, and anything the flake declares lands world-readable in the store. Leave it unmanaged." ];
    };
    "a runtime secret cannot go through dotfiles.mutable either" = {
      got = refused { dotfiles.mutable.".config/secrets.env" = { strategy = "seed"; text = "TOKEN=x"; }; };
      want = [ "~/.config/secrets.env is declared as dotfiles.mutable, but it holds secrets that infisical-sync fetches at runtime, and anything the flake declares lands world-readable in the store. Leave it unmanaged." ];
    };
    "a directory linked file by file cannot hold a file a runtime writer owns" = {
      got = refused { xdg.configFile.kitty = { source = ./fixtures/home-kitty; recursive = true; }; };
      want = [
        "~/.config/kitty/kitty.conf is declared as a store link by fixture, inside the directory linked at ~/.config/kitty, but ${lmtt}"
        "~/.config/kitty/themes/lmtt-dark.conf is declared as a store link by fixture, inside the directory linked at ~/.config/kitty, but ${lmtt}"
      ];
    };
    "a recursive source that is a symlink to a directory is listed through the link" = {
      got = refused { xdg.configFile.kitty = { source = ./fixtures/home-kitty-link; recursive = true; }; };
      want = [
        "~/.config/kitty/kitty.conf is declared as a store link by fixture, inside the directory linked at ~/.config/kitty, but ${lmtt}"
        "~/.config/kitty/themes/lmtt-dark.conf is declared as a store link by fixture, inside the directory linked at ~/.config/kitty, but ${lmtt}"
      ];
    };
    "a path in another case is the same path on the Mac's volume" = {
      got = refused { home.file.".Tmux.conf".text = "x"; };
      want = [ "~/.Tmux.conf is declared as a store link by fixture, but ${lmtt}" ];
    };
    "a directory in another case is the same directory" = {
      got = refused { xdg.configFile."NVim".source = ./fixtures/home-dir; };
      want = [ "~/.config/NVim is declared as one store link by fixture, but ${sharedWhy}. ${sharedFix}" ];
    };
    "a directory linked as one cannot hold one either" = {
      got = refused { xdg.configFile.foot.source = ./fixtures/home-kitty; };
      want = [ "~/.config/foot/themes/lmtt-dark.conf is declared as a store link by fixture, inside the directory linked at ~/.config/foot, but ${lmtt}" ];
    };
    "a built directory over a runtime writer's file cannot be linked file by file" = {
      got = refused ({ pkgs, ... }: { xdg.configFile.kitty = { source = pkgs.emptyDirectory; recursive = true; }; });
      want = [ "~/.config/kitty is declared as a recursive store link by fixture from a source that is built, so its files cannot be listed at evaluation, and it could hold ~/.config/kitty/kitty.conf: lmtt writes theme files through symlinks, so a store link fails with EROFS. Use a source directory from the repo or a flake input, or link the files one by one." ];
    };
    "an ancestor of a runtime writer's directory cannot be one store link" = {
      got = refused { home.file.".local/share".source = ./fixtures/home-dir; };
      want = [ "~/.local/share is declared as one store link by fixture and would cover ~/.local/share/applications, but ${sharedWhy}. Link the files inside it one by one (recursive = true)." ];
    };
    "a directory that holds runtime secrets cannot be one store link" = {
      got = refused { xdg.configFile.infisical.source = ./fixtures/home-dir; };
      want = [ "~/.config/infisical is declared as one store link by fixture, but ${sharedWhy}. ${sharedFix}" ];
    };
    "~/.config as one store link is refused once for each kind of runtime writer" = {
      got = lib.length (refused { home.file.".config".source = ./fixtures/home-dir; });
      want = 4;
    };
    "an ancestor linked file by file is fine" = {
      got = refused { home.file.".config" = { source = ./fixtures/home-dir; recursive = true; }; };
      want = [ ];
    };
    "a leading ./ does not hide a path" = {
      got = refused { home.file."./.tmux.conf".text = "x"; };
      want = [ "~/.tmux.conf is declared as a store link by fixture, but ${lmtt}" ];
    };
    "doubled and trailing slashes do not hide a path" = {
      got = refused { xdg.configFile."kitty//lmtt-colors.conf/".text = "x"; };
      want = [ "~/.config/kitty/lmtt-colors.conf is declared as a store link by fixture, but ${lmtt}" ];
    };
    "a trailing slash does not hide a directory" = {
      got = refused { xdg.configFile."nvim/".source = ./fixtures/home-dir; };
      want = [ "~/.config/nvim is declared as one store link by fixture, but ${sharedWhy}. ${sharedFix}" ];
    };
    "a path that is not normalised does not hide a secret from dotfiles.mutable" = {
      got = refused { dotfiles.mutable."./.config//secrets.env" = { strategy = "seed"; text = "TOKEN=x"; }; };
      want = [ "~/.config/secrets.env is declared as dotfiles.mutable, but it holds secrets that infisical-sync fetches at runtime, and anything the flake declares lands world-readable in the store. Leave it unmanaged." ];
    };
    "xdg.dataFile is refused and attributed like xdg.configFile" = {
      got = refused { xdg.dataFile.applications.source = ./fixtures/home-dir; };
      want = [ "~/.local/share/applications is declared as one store link by fixture, but ${sharedWhy}. ${sharedFix}" ];
    };
    "a file that a home-manager program module writes is refused" = {
      got = refused { programs.tmux.enable = true; };
      want = [ "~/.config/tmux/tmux.conf is declared as a store link by home-manager's programs.tmux (enabled by fixture), but ${lmtt}" ];
    };
    "an ordinary file is a store link" = {
      got = refused { xdg.configFile."kitty/tab_bar.py".text = "x"; };
      want = [ ];
    };
    "a fragment its owner reads is fine" = {
      got = refusedOn [ "wm" ] { dotfiles.fragments."wm/rules" = "rule"; };
      want = [ ];
    };
    "a fragment whose owner is not enabled is an error" = {
      got = refusedOn [ "bar" ] { dotfiles.fragments."wm/rules" = "rule"; };
      want = [ "dotfiles.fragments.\"wm/rules\" (set by fixture) goes nowhere: wm reads it and is not enabled on this machine. Require wm, or set the fragment only when lib.elem \"wm\" machine.enabled." ];
    };
    "a fragment key no solution reads is an error" = {
      got = refusedOn [ "wm" ] { dotfiles.fragments."wm/rulez" = "rule"; };
      want = [ "dotfiles.fragments.\"wm/rulez\" (set by fixture) names a key no solution reads. The solution that assembles the file lists its keys in `fragments`. Known keys: wm/rules." ];
    };
    "a fragment set only when its owner is enabled is fine" = {
      got = refusedOn [ "bar" ] ({ lib, machine, ... }: { dotfiles.fragments."wm/rules" = lib.mkIf (lib.elem "wm" machine.enabled) "rule"; });
      want = [ ];
    };
  };
in
lib.mapAttrsToList
  (name: c: "${name}: got ${builtins.toJSON c.got}, want ${builtins.toJSON c.want}")
  (lib.filterAttrs (_: c: c.got != c.want) cases)

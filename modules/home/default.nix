{ config, options, lib, machine, owners, fragmentOwners, modulesPath, ... }:
let
  who = import ./who.nix { inherit lib options owners modulesPath; };
  setBy = key:
    let found = who.named (who.definers options.dotfiles.fragments key); in
    if found == [ ] then "" else " (set by ${lib.concatStringsSep ", " found})";

  unread = key:
    let owner = fragmentOwners.${key} or null; in
    if owner == null then
      "dotfiles.fragments.\"${key}\"${setBy key} names a key no solution reads. The solution that assembles the file lists its keys in `fragments`. Known keys: ${toString (lib.attrNames fragmentOwners)}."
    else if !lib.elem owner machine.enabled then
      "dotfiles.fragments.\"${key}\"${setBy key} goes nowhere: ${owner} reads it and is not enabled on this machine. Require ${owner}, or set the fragment only when lib.elem \"${owner}\" machine.enabled."
    else null;
in
{
  imports = [ ./services.nix ./mutable.nix ./guard.nix ./root.nix ./report.nix ./credentials.nix ./packages.nix ./build-trust.nix ];

  options.dotfiles.fragments = lib.mkOption {
    type = lib.types.attrsOf lib.types.lines;
    default = { };
    example = lib.literalExpression ''{ "hypr/autostart" = "hl.exec_cmd(\"uwsm app -- discord\")"; }'';
    description = ''
      Text contributed to a file that one solution owns and several feed. The
      owner lists the keys it reads in its `fragments` metadata and assembles the
      file. Order with `lib.mkBefore` and `lib.mkAfter`. A key no solution lists,
      or one whose owner is not enabled on the machine, is an evaluation error.
    '';
  };

  config = {
    assertions = map (message: { assertion = false; inherit message; })
      (lib.filter (m: m != null) (map unread (lib.attrNames config.dotfiles.fragments)));

    home = {
      username = machine.user.name;
      homeDirectory = machine.user.home;
      stateVersion = "26.05";
    };
    manual.manpages.enable = false;
  };
}

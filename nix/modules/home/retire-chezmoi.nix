{ pkgs }:
pkgs.writeScript "retire-chezmoi" (builtins.replaceStrings
  [ "#!/usr/bin/env bash" "@git@" ]
  [ "#!${pkgs.runtimeShell}" "${pkgs.git}/bin/git" ]
  (builtins.readFile ./retire-chezmoi.sh))

{ lib, pkgs, machine, ... }:
let
  given = machine.private.packages or [ ];
  names = if lib.isList given then given else given.${if pkgs.stdenv.hostPlatform.isDarwin then "darwin" else "linux"} or [ ];
  resolve = name:
    lib.attrByPath (lib.splitString "." name)
      (throw "${machine.name or "this machine"}: private.packages names ${name}, which nixpkgs does not have")
      pkgs;
in
{
  home.packages = map resolve names;
}

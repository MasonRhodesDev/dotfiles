{ inputs, pkgs }:
{ modules, owners ? { }, enabled ? [ ], fragmentOwners ? { } }:
let
  hm = inputs.home-manager;
  lib = import "${hm}/modules/lib/stdlib-extended.nix" pkgs.lib;
in
lib.evalModules {
  class = "homeManager";
  modules = [ ../modules/home ] ++ modules ++ import "${hm}/modules/modules.nix" { inherit lib pkgs; };
  specialArgs = {
    modulesPath = "${hm}/modules";
    inherit inputs owners fragmentOwners;
    identity = { };
    machine = {
      inherit enabled;
      user = {
        name = "fixture";
        home = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/fixture" else "/home/fixture";
      };
    };
  };
}

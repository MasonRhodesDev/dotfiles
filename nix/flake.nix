{
  description = "One flake for every machine. Each solution says when it applies, and the private repo states the traits of each machine.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    private = {
      url = "path:./private-stub";
      flake = false;
    };

    hypr-de = {
      url = "github:MasonRhodesDev/hypr-DE";
      flake = false;
    };
  };

  outputs = inputs:
    let
      dot = import ./lib { inherit inputs; };
      inherit (dot) lib;
      machines = dot.machinesFrom inputs.private;
      configurations = platform:
        lib.mapAttrs (_: m: m.configuration) (lib.filterAttrs (_: m: m.platform == platform) machines);
      perSystem = f: lib.genAttrs dot.systems (system: f inputs.nixpkgs.legacyPackages.${system});
    in
    {
      homeConfigurations = configurations "linux";
      darwinConfigurations = configurations "darwin";

      lib = {
        inherit (dot) resolve;
        traits = dot.catalog.traits.schema;
        machines = lib.mapAttrs (_: m: { inherit (m) system traits user enabled why starts summary build secretsAudit secretsUnchecked; }) machines;
      };

      checks = perSystem (pkgs: import ./checks { inherit dot inputs pkgs; });
      packages = perSystem (pkgs: { dot = pkgs.writeScriptBin "dot" (builtins.readFile ./dot); });
    };
}

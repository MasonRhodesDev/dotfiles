{ inputs }:
let
  inherit (inputs.nixpkgs) lib;
  traitsFor = import ./traits.nix { inherit lib; };
  inherit (import ./catalog.nix { inherit lib traitsFor; }) loadCatalog partsOf platformOf systems;

  resolveIn = import ./resolve.nix { inherit lib platformOf; };
  catalog = loadCatalog (import ../traits.nix) ../solutions;
  resolve = resolveIn catalog;

  inherit (import ./machines.nix { inherit lib inputs catalog resolve partsOf platformOf systems; })
    machinesFrom machineFrom;
in
{ inherit lib catalog resolve resolveIn loadCatalog machinesFrom machineFrom systems; }

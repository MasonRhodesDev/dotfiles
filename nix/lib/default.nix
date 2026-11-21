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

  tree = machines:
    let
      empty = { starts = { linux = [ ]; darwin = [ ]; root = [ ]; }; files = [ ]; scripts = [ ]; packages = { linux = [ ]; darwin = [ ]; }; };
      node = id:
        let n = catalog.nodes.${id}; in
        (if n.kind != "solution" then {
          inherit (n) kind id name description;
          children = map node n.children;
        } else
          lib.recursiveUpdate empty (n.inventory or { }) // {
            inherit (n) kind id name description platforms requires conflicts;
            implemented = lib.attrNames n.parts;
            questions = [ ];
          } // lib.optionalAttrs (n.only != null) { inherit (n) only; })
        // lib.optionalAttrs (n.when != { }) { inherit (n) when; };
    in
    {
      version = 3;
      source = "nix eval --json .#lib.tree";
      groups = map node catalog.roots;
      traits = lib.mapAttrsToList (id: t: { inherit id; } // t) catalog.traits.schema;
      machines = lib.mapAttrsToList (id: m: { inherit id; inherit (m) system traits include exclude; }) machines;
      questions = [ ];
      drop = import ../parity/drop.nix;
    };
in
{ inherit lib catalog resolve resolveIn loadCatalog machinesFrom machineFrom tree systems; }

{ lib, inputs, catalog, resolve, partsOf, platformOf, systems }:
let
  required = [ "system" "traits" "user" ];
  optional = [ "include" "exclude" "private" "extraModules" ];
  stated = facts: lib.concatStringsSep ", " (lib.mapAttrsToList (trait: value: "${trait} = ${builtins.toJSON value}") facts);

  problems = raw:
    map (k: "unknown key '${k}'") (lib.subtractLists (required ++ optional) (lib.attrNames raw))
    ++ map (k: "missing '${k}'") (lib.filter (k: !(raw ? ${k})) required)
    ++ lib.optional (raw ? system && !lib.elem raw.system systems)
      "system '${raw.system}' is not one of ${toString systems}"
    ++ lib.optionals (raw ? traits) (catalog.traits.problems raw.traits)
    ++ lib.optional (raw ? user && !(raw.user ? name && raw.user ? home)) "user needs name and home";

  extra = file: index: raw: {
    id = "extra-${toString index}";
    file = "${file} extraModules[${toString index}]";
    parts = partsOf raw;
  };

  compose = machine: solutions:
    let
      has = slot: lib.filter (s: s.parts ? ${slot}) solutions;
      located = slot: map (s: lib.setDefaultModuleLocation "${s.file}#${slot}" s.parts.${slot}) (has slot);
      rootSteps = map
        (s: { pkgs, ... }@args: {
          _file = "${s.file}#linux.root";
          dotfiles.root.${s.id} = lib.toFunction s.parts."linux.root" args;
        })
        (has "linux.root");
      homeModules = [ ../modules/home ] ++ located "home" ++ located "${machine.platform}.home"
        ++ lib.optionals (machine.platform == "linux") rootSteps;
      specialArgs = {
        inherit inputs;
        inherit (machine) identity;
        inherit (catalog) fragmentOwners;
        machine = removeAttrs machine [ "identity" ];
        owners = lib.listToAttrs (lib.concatMap
          (s: map (slot: lib.nameValuePair "${s.file}#${slot}" s.id) (lib.attrNames s.parts))
          solutions);
      };
    in
    if machine.platform == "darwin" then
      inputs.nix-darwin.lib.darwinSystem
        {
          specialArgs = specialArgs // { inherit homeModules; };
          modules = [ ../modules/darwin.nix ] ++ located "darwin.system";
        }
    else
      inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages.${machine.system};
        extraSpecialArgs = specialArgs;
        modules = homeModules;
      };

  machine = identity: name: file: raw:
    let
      found = problems raw;
      entry = if found == [ ] then raw else throw "${file}: ${lib.concatStringsSep "; " found}";
      inherit (entry) system;
      platform = platformOf (raw.system or "");
      traits = catalog.traits.fill entry.traits;
      include = entry.include or [ ];
      exclude = entry.exclude or [ ];

      resolution = resolve { inherit system traits include exclude; };
      checked =
        if resolution.errors == [ ] then resolution
        else throw ''
          machine '${name}' (${stated traits} on ${system}) does not resolve:
          ${lib.concatMapStrings (e: "  - ${e}\n") resolution.errors}'';

      extras = lib.imap0 (extra file) (entry.extraModules or [ ]);
      data = {
        inherit name system platform traits include exclude;
        inherit (entry) user;
        private = entry.private or { };
        inherit (checked) enabled;
      };
      configuration = compose (data // { inherit identity; })
        (map (id: catalog.solutions.${id}) checked.enabled ++ extras);
      home =
        if platform == "darwin" then configuration.config.home-manager.users.${entry.user.name}
        else configuration.config;
      starts = home.dotfiles.report.starts
        ++ lib.optionals (platform == "darwin") configuration.config.dotfiles.report.starts;
    in
    data // {
      inherit resolution configuration starts;
      extraModules = lib.length extras;
      build = if platform == "darwin" then configuration.system else configuration.activationPackage;
      inherit (home.dotfiles) secretsAudit;
      secretsUnchecked = lib.genAttrs systems (s:
        let tool = import ../modules/home/credential-tool.nix { pkgs = inputs.nixpkgs.legacyPackages.${s}; }; in
        tool.audit (tool.program home.dotfiles.secretsReport null));
      manifest = import ../parity/manifest.nix {
        inherit lib home;
        pkgs = inputs.nixpkgs.legacyPackages.${system};
      };
      why = lib.mapAttrs
        (id: conditions:
          let
            solution = catalog.solutions.${id};
            consulted = lib.unique (lib.concatMap (c: lib.attrNames c.when) conditions);
          in
          lib.concatStringsSep "\n" (
            if conditions == [ ] then [ "${solution.file}: nothing above it has a when, so every machine gets it" ]
            else
              [ "${file}: ${stated (lib.getAttrs consulted traits)}" ]
              ++ map (c: "${catalog.nodes.${c.node}.file}: when ${stated c.when}") conditions
              ++ lib.optional (solution.when == { }) "${solution.file}: the solution"
          ))
        checked.why;
      summary = ''
        ${name} on ${system}, ${toString (lib.length checked.enabled)} solutions

        traits
        ${lib.concatStrings (lib.mapAttrsToList (trait: value: "  ${trait} = ${builtins.toJSON value}\n") traits)}
        starts
        ${lib.concatMapStrings (s: "  ${lib.fixedWidthString 6 " " s.scope}  ${s.what}  (${if s.solution == null then "not from a solution" else s.solution})\n") starts}
        solutions
        ${lib.concatMapStrings (id: "  ${id}\n") checked.enabled}'';
    };
in
{
  machineFrom = machine;

  machinesFrom = src:
    let identity = import (src + "/identity.nix"); in
    lib.mapAttrs'
      (entry: _:
        let name = lib.removeSuffix ".nix" entry; in
        lib.nameValuePair name (machine identity name "machines/${entry}" (import (src + "/machines/${entry}"))))
      (lib.filterAttrs (entry: type: type == "regular" && lib.hasSuffix ".nix" entry)
        (builtins.readDir (src + "/machines")));
}

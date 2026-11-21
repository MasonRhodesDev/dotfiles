{ config, options, lib, pkgs, owners, machine, ... }:
let
  inherit (pkgs.stdenv.hostPlatform) isLinux isDarwin;

  ownersOf = option:
    lib.listToAttrs (lib.concatMap
      (def: map (name: lib.nameValuePair name (owners.${toString def.file} or null)) (lib.attrNames def.value))
      (lib.filter (def: owners ? ${toString def.file}) option.definitionsWithLocations));

  fromServices = ownersOf options.dotfiles.services;
  fromEnable = name:
    lib.findFirst (id: id != null) null (lib.concatMap
      (kind: map (def: owners.${toString def.file} or null)
        (options.${kind}.${name}.enable.definitionsWithLocations or [ ]))
      [ "programs" "services" ]);
  start = scope: declared: what: name: {
    inherit what scope;
    solution = fromServices.${name} or declared.${name} or (fromEnable name);
  };

  unitKinds = { services = "service"; timers = "timer"; sockets = "socket"; paths = "path"; };
  userUnits = lib.concatLists (lib.mapAttrsToList
    (kind: suffix:
      lib.mapAttrsToList (name: _: start "user" (ownersOf options.systemd.user.${kind}) "${name}.${suffix}" name)
        (lib.filterAttrs (_: unit: (unit.Install.WantedBy or [ ]) != [ ]) config.systemd.user.${kind}))
    unitKinds);

  agents = lib.mapAttrsToList (name: _: start "user" (ownersOf options.launchd.agents) "launchd agent ${name}" name)
    (lib.filterAttrs (_: agent: agent.enable) config.launchd.agents);

  rootUnits = lib.concatLists (lib.mapAttrsToList
    (id: step: map (unit: { what = unit; scope = "root"; solution = id; }) step.units)
    config.dotfiles.root);
in
{
  options.dotfiles.report = lib.mkOption {
    type = lib.types.raw;
    readOnly = true;
    description = "Derived facts about this configuration. `starts` lists what runs without being asked.";
  };

  options.dotfiles.warnings = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Lines that dot plan and dot switch show for this machine, carried in the generation.";
  };

  config.dotfiles.report = {
    starts = lib.optionals isLinux (userUnits ++ rootUnits) ++ lib.optionals isDarwin agents;
    serviceOwners = fromServices;
  };

  config.home.extraBuilderCommands = lib.mkMerge [
    (lib.mkIf (config.dotfiles.warnings != [ ])
      "cp ${pkgs.writeText "dotfiles-warnings" (lib.concatMapStrings (w: "${w}\n") config.dotfiles.warnings)} $out/dotfiles-warnings")
    (lib.mkIf (machine.private ? buildHost)
      "cp ${pkgs.writeText "dotfiles-build-host" "${machine.private.buildHost}\n"} $out/dotfiles-build-host")
  ];
}

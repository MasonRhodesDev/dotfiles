{ config, options, lib, pkgs, inputs, machine, identity, owners, fragmentOwners, homeModules, ... }:
let
  panes = {
    extensions = "x-apple.systempreferences:com.apple.LoginItems-Settings.extension";
    accessibility = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility";
    input-monitoring = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent";
    full-disk = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles";
  };
  paneTitles = {
    extensions = "General > Login Items & Extensions";
    accessibility = "Privacy & Security > Accessibility";
    input-monitoring = "Privacy & Security > Input Monitoring";
    full-disk = "Privacy & Security > Full Disk Access";
  };
  permissionsTool = pkgs: pkgs.writeShellScriptBin "dotfiles-permissions" ''
    open_panes=0
    [ "''${1:-}" = --open ] && open_panes=1
    missing=0
    ${lib.concatStrings (lib.mapAttrsToList (name: p: ''
      if ! ( ${p.check}
      ) >/dev/null 2>&1; then
        missing=$((missing + 1))
        echo "missing: ${p.what}  (System Settings > ${paneTitles.${p.pane}})"
        if [ "$open_panes" = 1 ]; then
          open ${lib.escapeShellArg panes.${p.pane}}
          echo "  turn it on, then press Enter (or wait: this notices by itself)"
          for _ in $(seq 1 120); do
            if ( ${p.check}
            ) >/dev/null 2>&1; then echo "  granted"; missing=$((missing - 1)); break; fi
            read -r -t 2 _ && break
          done
        fi
      fi
    '') config.dotfiles.permissions)}
    [ "$missing" = 0 ] && echo "dotfiles-permissions: every declared grant is in place"
    exit "$missing"
  '';
  attributed = scope: option: nameOf:
    lib.concatMap
      (def: map (item: { what = nameOf item; inherit scope; solution = owners.${toString def.file} or null; }) def.value)
      option.definitionsWithLocations;
  daemonOwner = name:
    let
      fromService = config.home-manager.users.${machine.user.name}.dotfiles.report.serviceOwners.${name} or null;
      enabledBy = service: lib.findFirst (o: o != null) null
        (map (def: owners.${toString def.file} or null) (options.services.${service}.enable.definitionsWithLocations or [ ]));
      services = lib.filter (service: lib.hasPrefix service name && options.services.${service} ? enable) (lib.attrNames options.services);
    in
    if fromService != null then fromService else lib.findFirst (o: o != null) null (map enabledBy services);
in
{
  imports = [
    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew
  ];

  options.dotfiles.permissions = lib.mkOption {
    default = { };
    description = "Grants a solution needs that only the owner can click through, each with a check that exits 0 once granted.";
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        what = lib.mkOption { type = lib.types.str; description = "What to turn on, as the owner sees it in System Settings."; };
        pane = lib.mkOption { type = lib.types.enum (lib.attrNames panes); };
        check = lib.mkOption { type = lib.types.lines; description = "Shell run as the user; exit 0 means granted."; };
      };
    });
  };

  options.dotfiles.report = lib.mkOption {
    type = lib.types.raw;
    readOnly = true;
    description = "Derived facts about the system side. Casks count as starts because most register a login item.";
  };

  config = {
    dotfiles.report.starts =
      attributed "cask" options.homebrew.casks (cask: "cask ${cask.name or cask}")
      ++ map (name: { what = "launchd daemon ${name}"; scope = "root"; solution = daemonOwner name; })
        (lib.attrNames config.launchd.daemons);

    environment.systemPackages = [ (permissionsTool pkgs) ];

    launchd.daemons = lib.mkIf machine.traits.headless (lib.mapAttrs
      (_: job: {
        serviceConfig = job // {
          UserName = machine.user.name;
          GroupName = "staff";
          EnvironmentVariables = job.EnvironmentVariables // { HOME = machine.user.home; USER = machine.user.name; };
        };
      })
      config.home-manager.users.${machine.user.name}.dotfiles.launchd);

    system.systemBuilderCommands =
      let warnings = config.home-manager.users.${machine.user.name}.dotfiles.warnings; in
      lib.mkIf (warnings != [ ])
        "cp ${pkgs.writeText "dotfiles-warnings" (lib.concatMapStrings (w: "${w}\n") warnings)} $out/dotfiles-warnings";

    nix.enable = false;
    nixpkgs.hostPlatform = machine.system;
    system.stateVersion = 6;

    system.primaryUser = machine.user.name;
    users.users.${machine.user.name}.home = machine.user.home;

    homebrew.enable = true;
    nix-homebrew = {
      enable = true;
      user = machine.user.name;
      autoMigrate = true;
      trust.taps = map (tap: tap.name) config.homebrew.taps;
    };

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "pre-nix";
      extraSpecialArgs = { inherit inputs machine identity owners fragmentOwners; };
      users.${machine.user.name}.imports = homeModules;
    };
  };
}

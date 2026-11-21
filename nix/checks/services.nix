{ inputs, lib }:
let
  services = {
    waits = {
      command = [ "/opt/fixture/bin/daemon" "--serve" ];
      requiresFile = [ ".config/fixture/one.env" ".config/fixture/two.env" ];
      extraPath = [ "/opt/fixture/bin" "/opt/other/bin" ];
    };
    plain.command = [ "/opt/fixture/bin/daemon" ];
  };
  on = system:
    (import ./home.nix { inherit inputs; pkgs = inputs.nixpkgs.legacyPackages.${system}; } {
      modules = [{ dotfiles.services = services; }];
    }).config;
  linux = on "x86_64-linux";
  darwin = on "aarch64-darwin";

  conditions = name: linux.systemd.user.services.${name}.Unit.ConditionPathExists or [ ];
  agent = name: darwin.launchd.agents.${name}.config;
  pathOf = { linux = name: lib.removePrefix "PATH=" (lib.findFirst (lib.hasPrefix "PATH=") "" linux.systemd.user.services.${name}.Service.Environment); darwin = name: (agent name).EnvironmentVariables.PATH; };

  index = x: xs: (lib.lists.findFirstIndex (y: y == x) null xs);
  afterProfile = platform: config:
    let dirs = lib.splitString ":" (pathOf.${platform} "waits"); in
    map (dir: index dir dirs > index "${config.home.profileDirectory}/bin" dirs) services.waits.extraPath;

  arguments = (agent "waits").ProgramArguments;
  script = lib.elemAt arguments 2;
  waitsFor = file: lib.hasInfix "/bin/wait4path ${darwin.home.homeDirectory}/${file} &&" script;

  cases = {
    "systemd: a service that needs two files has a ConditionPathExists line for each" = {
      got = conditions "waits";
      want = [ "%h/.config/fixture/one.env" "%h/.config/fixture/two.env" ];
    };
    "systemd: a service that needs no file has no condition" = {
      got = conditions "plain";
      want = [ ];
    };
    "systemd: a service's extra directories come after the profile in PATH" = {
      got = afterProfile "linux" linux;
      want = [ true true ];
    };
    "launchd: a service that needs two files waits for both with /bin/wait4path, then runs its command" = {
      got = {
        shell = lib.take 2 arguments;
        waits = map waitsFor services.waits.requiresFile;
        runs = lib.hasSuffix "exec \"$@\"" script;
        command = lib.drop 4 arguments;
      };
      want = { shell = [ "/bin/sh" "-c" ]; waits = [ true true ]; runs = true; inherit (services.waits) command; };
    };
    "launchd: a service that needs a file does not start at load" = {
      got = (agent "waits").RunAtLoad;
      want = false;
    };
    "launchd: a service that needs no file starts at load, with its command as it is" = {
      got = { inherit (agent "plain") RunAtLoad ProgramArguments; };
      want = { RunAtLoad = true; ProgramArguments = services.plain.command; };
    };
    "launchd: a service's extra directories come after the profile in PATH" = {
      got = afterProfile "darwin" darwin;
      want = [ true true ];
    };
  };
in
lib.mapAttrsToList
  (name: c: "${name}: got ${builtins.toJSON c.got}, want ${builtins.toJSON c.want}")
  (lib.filterAttrs (_: c: c.got != c.want) cases)

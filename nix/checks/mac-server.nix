{ dot, lib }:
let
  identity = import ../private-stub/identity.nix;
  stub = dot.machinesFrom ../private-stub;
  entries = {
    server = import ../private-stub/machines/stub-work-mac-server.nix;
    laptop = import ../private-stub/machines/stub-work-laptop.nix;
    headless = import ../private-stub/machines/stub-headless.nix;
  };
  variant = base: name: change: dot.machineFrom identity name "stub ${name}" (change entries.${base});
  withTraits = traits: entry: entry // { traits = entry.traits // traits; };

  server = stub.stub-work-mac-server;
  serverWithGui = variant "server" "server with a GUI" (withTraits { headless = false; uses = [ "dev" "ios-dev" ]; });
  serverWithoutIos = variant "server" "server without ios-dev" (withTraits { uses = [ "dev" "agent-hosting" ]; });
  linuxWithIos = variant "headless" "Linux server with ios-dev" (withTraits { uses = [ "dev" "agent-hosting" "ios-dev" ]; });
  serverWithoutKeys = variant "server" "server without authorized keys" (entry: entry // { private = removeAttrs entry.private [ "authorizedKeys" ]; });
  serverWithRbw = variant "server" "server with rbw in its package list" (entry: entry // { private = entry.private // { packages = [ "rbw" ]; }; });
  serverWithRbwAndGui = variant "server" "server with rbw and a GUI" (entry: withTraits { headless = false; uses = [ "dev" "ios-dev" ]; } (entry // { private = entry.private // { packages = [ "rbw" ]; }; }));
  laptopWithoutServer = variant "laptop" "work laptop without the Mac server entry" (entry: entry // { private = removeAttrs entry.private [ "workMacServer" ]; });

  system = m: m.configuration.config;
  home = m: if m.platform == "darwin" then (system m).home-manager.users.${m.user.name} else system m;
  gui = m:
    let c = system m; in
    {
      casks = map (cask: cask.name or cask) c.homebrew.casks;
      appStore = lib.attrNames c.homebrew.masApps;
      defaults = lib.filter (lib.hasInfix "defaults write") (lib.splitString "\n" (c.system.activationScripts.defaults.text + c.system.activationScripts.userDefaults.text));
      agents = lib.attrNames (lib.filterAttrs (_: a: a.enable) (home m).launchd.agents) ++ lib.attrNames c.launchd.user.agents;
    };
  daemons = m: lib.filterAttrs (name: _: name != "activate-system") (system m).launchd.daemons;
  sshd = m: { keys = (system m).users.users.${m.user.name}.openssh.authorizedKeys.keys; inherit ((system m).services.openssh) extraConfig; };
  rbwPinentry = m: ((home m).dotfiles.mutable."Library/Application Support/rbw/config.json" or { json = { }; }).json.pinentry or null;
  rootJoin = m: lib.hasInfix "-tailscale-join " (system m).system.activationScripts.postActivation.text;
  userJoin = m: (home m).home.activation ? tailscaleJoin;
  xcodeSetup = m: lib.hasInfix "-xcode-setup " (system m).system.activationScripts.postActivation.text;
  nodeOnSshPath = m: (home m).home.file ? ".local/bin/node";
  sshConfig = m: (home m).home.file.".ssh/config".text or "";
  hasHost = host: m: lib.hasInfix "\nHost ${host}\n" "\n${sshConfig m}";

  expect = what: got: want: lib.optional (got != want) "${what}: got ${builtins.toJSON got}, want ${builtins.toJSON want}";
  holds = what: ok: lib.optional (!ok) what;
in
expect "the headless Mac server gets no cask" (gui server).casks [ ]
++ expect "the headless Mac server gets no App Store app" (gui server).appStore [ ]
++ expect "the headless Mac server writes no macOS defaults" (gui server).defaults [ ]
++ expect "the headless Mac server starts no launchd agent, which would wait for a GUI login" (gui server).agents [ ]
++ expect "the headless Mac server starts its services as launchd daemons at boot" (lib.attrNames (daemons server)) [ "dotfiles-session-env" "herdr" "secret-inbox" "t3code" "tailscaled" ]
++ lib.concatLists (lib.mapAttrsToList (name: d: expect "the ${name} daemon runs as the user" (d.serviceConfig.UserName or null) server.user.name)
    (removeAttrs (daemons server) [ "tailscaled" ]))
++ expect "the headless Mac server runs the open-source tailscaled" (system server).services.tailscale.enable true
++ holds "the headless Mac server joins the tailnet as root in system activation, since its tailscaled has no user operator" (rootJoin server && !userJoin server)
++ holds "the same Mac with a GUI joins as the user through the Tailscale app, not as root" (userJoin serverWithGui && !rootJoin serverWithGui)
++ holds "a Mac laptop joins as the user" (userJoin stub.stub-thin-mac && !rootJoin stub.stub-thin-mac)
++ expect "the T3 daemon runs t3 for LAN and tailnet access" (daemons server).t3code.serviceConfig.ProgramArguments [ "/Users/alex/.local/bin/t3" "--lan" "--no-browser" ]
++ holds "herdr comes from Homebrew on the Mac server" (lib.elem "herdr" (map (b: b.name or b) (system server).homebrew.brews))
++ expect "the same Mac with a GUI starts no service daemon" (lib.attrNames (daemons serverWithGui)) [ ]
++ holds "the same Mac with a GUI gets the Tailscale app" (lib.elem "tailscale-app" (gui serverWithGui).casks)
++ holds "the same Mac with a GUI leaves T3 to t3 up" (!((home serverWithGui).dotfiles.services ? t3code))
++ expect "the Mac server takes its authorized keys from the private entry" (sshd server).keys [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEXAMPLEexampleEXAMPLEexampleEXAMPLEexample0 stub-key" ]
++ expect "with a key, the Mac server refuses passwords" (sshd server).extraConfig "PasswordAuthentication no\nKbdInteractiveAuthentication no\n"
++ expect "without a key, the Mac server keeps password login" (sshd serverWithoutKeys) { keys = [ ]; extraConfig = ""; }
++ holds "rbw on the headless Mac asks through pinentry-curses" (lib.hasSuffix "/bin/pinentry-curses" (toString (rbwPinentry serverWithRbw)))
++ expect "rbw on a Mac with a GUI keeps its own pinentry" (rbwPinentry serverWithRbwAndGui) null
++ expect "a headless Mac without rbw gets no rbw config" (rbwPinentry server) null
++ holds "the same Mac with a GUI gets GUI casks, so the cask list can see them" (lib.length (gui serverWithGui).casks > 1)
++ holds "the same Mac with a GUI writes macOS defaults, so the defaults list can see them" ((gui serverWithGui).defaults != [ ])
++ holds "the same Mac with a GUI starts GUI agents, so the agent list can see them" (lib.length (gui serverWithGui).agents > lib.length (gui server).agents)
++ expect "the headless Mac server turns on Remote Login" (system server).services.openssh.enable true
++ expect "a Mac laptop leaves Remote Login to macOS" (system stub.stub-thin-mac).services.openssh.enable null
++ holds "the Mac server hosts T3 agents with its own launchd agent setup" ((home server).home.activation ? t3code)
++ holds "ios-dev sets up Xcode on the Mac server" (xcodeSetup server)
++ holds "ios-dev puts node on the Mac server's SSH PATH for T3's device tools" (nodeOnSshPath server)
++ holds "without ios-dev, the Mac server sets up no Xcode" (!xcodeSetup serverWithoutIos)
++ holds "without ios-dev, the Mac server links no node into ~/.local/bin" (!nodeOnSshPath serverWithoutIos)
++ lib.concatMap (id: holds "${id} is darwin only, so a Linux server with ios-dev skips it" (!lib.elem id linuxWithIos.enabled)) [ "xcode" "t3-device-host" ]
++ holds "the work laptop has a work-mac Host at the private address" (hasHost "work-mac" stub.stub-work-laptop && lib.hasInfix "HostName work-mac.example.invalid" (sshConfig stub.stub-work-laptop))
++ holds "without the private entry, the work laptop has no work-mac Host" (!hasHost "work-mac" laptopWithoutServer)
++ lib.concatMap (m: holds "${m.name} has no work-mac Host" (!hasHost "work-mac" m)) [ server stub.stub-gaming-desktop stub.stub-headless stub.stub-thin-mac ]

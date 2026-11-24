{ dot, lib }:
let
  identity = import ../private-stub/identity.nix;
  stub = dot.machinesFrom ../private-stub;
  desktopEntry = import ../private-stub/machines/stub-gaming-desktop.nix;
  desktop = dot.machineFrom identity "desktop hosting agents" "stub desktop hosting agents"
    (desktopEntry // { traits = desktopEntry.traits // { uses = desktopEntry.traits.uses ++ [ "agent-hosting" ]; }; });
  headless = stub.stub-headless;

  home = m: m.configuration.config;
  has = id: m: lib.elem id m.resolution.enabled or [ ];
  pairUnit = m: (home m).systemd.user.services ? t3-desktop-pair;
  linger = m: lib.hasInfix "loginctl enable-linger" ((home m).dotfiles.root.t3code-server.script or "");

  expect = what: got: want: lib.optional (got != want) "${what}: got ${builtins.toJSON got}, want ${builtins.toJSON want}";
  holds = what: ok: lib.optional (!ok) what;
in
expect "a desktop that hosts agents resolves" desktop.resolution.errors [ ]
++ holds "a desktop that hosts agents runs the T3 service and its window manager together" (has "t3code-server" desktop && has "window-manager" desktop)
++ holds "a desktop that hosts agents pairs the T3 app with the service at login" (pairUnit desktop)
++ holds "a desktop that hosts agents installs t3-desktop-client" ((home desktop).home.file ? ".local/bin/t3-desktop-client")
++ holds "a desktop that hosts agents runs t3-desktop-client after T3 is installed" (lib.elem "t3code" (home desktop).home.activation.t3codeClient.after)
++ holds "a desktop leaves t3 up to t3-desktop-client, which first checks that the app does not host a server" (!lib.hasInfix "up --lan --yes" (home desktop).home.activation.t3code.data)
++ expect "the pairing unit starts with the graphical session" (home desktop).systemd.user.services.t3-desktop-pair.Install.WantedBy [ "graphical-session.target" ]
++ holds "a headless agent host runs t3 up itself" (lib.hasInfix "up --lan --yes" (home headless).home.activation.t3code.data)
++ holds "a headless agent host has no T3 app to pair" (!pairUnit headless && !((home headless).home.file ? ".local/bin/t3-desktop-client"))
++ holds "the T3 service starts at boot on a desktop, through linger" (linger desktop)
++ holds "the T3 service starts at boot on a headless agent host, through linger" (linger headless)
++ holds "t3 up is skipped while the T3 app's own server runs" (lib.hasInfix "apps/server/dist/bin" (home headless).home.activation.t3code.data)

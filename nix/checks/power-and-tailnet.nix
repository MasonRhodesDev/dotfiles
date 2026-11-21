{ dot, lib }:
let
  identity = import ../private-stub/identity.nix;
  entries = {
    linux = import ../private-stub/machines/stub-work-laptop.nix;
    darwin = import ../private-stub/machines/stub-thin-mac.nix;
  };
  variant = platform: traits:
    let entry = entries.${platform}; in
    dot.machineFrom identity "${platform} ${builtins.toJSON traits}" "stub ${platform} variant" (entry // { traits = entry.traits // traits; });

  linux = {
    laptop = variant "linux" { form = "laptop"; };
    desktop = variant "linux" { form = "desktop"; };
    server = variant "linux" { form = "server"; };
    headless-desktop = variant "linux" { form = "desktop"; headless = true; hardware = [ ]; };
    without-secrets = variant "linux" { secrets = "none"; };
    bitwarden = variant "linux" { secrets = "bitwarden"; };
  };
  darwin = {
    laptop = variant "darwin" { form = "laptop"; };
    desktop = variant "darwin" { form = "desktop"; };
    server = variant "darwin" { form = "server"; };
    without-secrets = variant "darwin" { secrets = "none"; };
    bitwarden = variant "darwin" { secrets = "bitwarden"; };
  };

  hypridle = m: m.configuration.config.xdg.configFile."hypr-de/hypridle.conf".text or null;
  sleep = m: { inherit (m.configuration.config.power.sleep) computer display; inherit (m.configuration.config.power) restartAfterPowerFailure; };
  dispatcher = m: lib.any (step: lib.any (lib.hasPrefix "/etc/NetworkManager/dispatcher.d/") (lib.attrNames step.files))
    (lib.attrValues m.configuration.config.dotfiles.root);

  expect = what: got: want: lib.optional (got != want) "${what}: got ${builtins.toJSON got}, want ${builtins.toJSON want}";
  all = lib.attrValues linux ++ lib.attrValues darwin ++ lib.attrValues (dot.machinesFrom ../private-stub);
in
expect "a Linux laptop suspends after 5 minutes" (hypridle linux.laptop) "$suspend_timeout = 300\n"
++ expect "a Linux desktop suspends after 30 minutes" (hypridle linux.desktop) "$suspend_timeout = 1800\n"
++ expect "a Linux server writes no suspend override" (hypridle linux.server) null
++ expect "a Linux desktop with no graphical session writes no suspend override" (hypridle linux.headless-desktop) null
++ expect "a Mac laptop sleeps after 5 minutes and its display after 3" (sleep darwin.laptop) { computer = 5; display = 3; restartAfterPowerFailure = null; }
++ expect "a Mac desktop sleeps after 30 minutes and leaves the display to the OS" (sleep darwin.desktop) { computer = 30; display = null; restartAfterPowerFailure = null; }
++ expect "a Mac server never sleeps and starts again after a power failure" (sleep darwin.server) { computer = "never"; display = null; restartAfterPowerFailure = true; }
++ expect "the headless work Mac server stub never sleeps and starts again after a power failure" (sleep (dot.machinesFrom ../private-stub).stub-work-mac-server) { computer = "never"; display = null; restartAfterPowerFailure = true; }
++ lib.concatMap
  (m: lib.concatMap (id: lib.optional (!lib.elem id m.enabled) "${m.name}: ${id} is core and not enabled") [ "suspend" "tailscale" ])
  all
++ lib.concatMap
  (m: lib.optional (lib.elem "tailscale-roaming" m.enabled != (m.traits.form == "laptop" && m.platform == "linux"))
    "${m.name}: tailscale-roaming is ${if lib.elem "tailscale-roaming" m.enabled then "enabled" else "missing"} on a ${m.platform} ${m.traits.form}")
  all
++ lib.concatMap
  (m: lib.optional (dispatcher m != (m.traits.form == "laptop"))
    "${m.name}: the roam-up dispatcher is ${if dispatcher m then "installed" else "missing"} on a ${m.traits.form}")
  (lib.attrValues linux)
++ lib.concatMap
  (m: lib.concatMap
    (id: lib.optional (lib.elem id m.enabled != (m.traits.secrets == "infisical"))
      "${m.name}: ${id} is ${if lib.elem id m.enabled then "enabled" else "missing"} with secrets = ${m.traits.secrets}")
    [ "infisical-provider" "infisical-sync" "secret-inbox" ])
  all
++ lib.concatMap
  (m: lib.concatMap
    (id: lib.optional (lib.elem id m.enabled != (m.traits.secrets == "bitwarden"))
      "${m.name}: ${id} is ${if lib.elem id m.enabled then "enabled" else "missing"} with secrets = ${m.traits.secrets}")
    [ "bitwarden-provider" "bitwarden-sync" ])
  all
++ expect "a Mac with secrets = bitwarden runs the session env writer as a launchd agent fed by the Bitwarden env project"
  (lib.any (lib.hasInfix "bitwarden-env-project")
    (darwin.bitwarden.configuration.config.home-manager.users.${entries.darwin.user.name}.launchd.agents.dotfiles-session-env.config.ProgramArguments or [ ]))
  true

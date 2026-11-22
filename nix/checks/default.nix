{ dot, inputs, pkgs }:
let
  inherit (dot) lib;
  stub = dot.machinesFrom ../private-stub;
  real = dot.machinesFrom inputs.private;
  evalHome = import ./home.nix { inherit inputs pkgs; };

  decided = name: failures:
    if failures == [ ] then pkgs.runCommand "check-${name}" { } "touch $out"
    else throw "check ${name} failed:\n${lib.concatMapStrings (f: "  - ${f}\n") failures}";

  optional = {
    private = [ "internalPanel" "dgpuPci" "softMixerNodes" "xwaylandPrimary" "infisical" "workMacServer" "packages" "bedrock" "buildHost" ];
    identity = [ "work" "tailnets" "buildHosts" ];
  };
  without =
    let
      identity = import ../private-stub/identity.nix;
      entry = import ../private-stub/machines/stub-work-laptop.nix;
      missing = lib.subtractLists (lib.attrNames entry.private) optional.private ++ lib.subtractLists (lib.attrNames identity) optional.identity;
      variant = name: identity: entry: { inherit name; machine = dot.machineFrom identity name "stub-work-laptop, ${name}" entry; };
    in
    if missing != [ ] then throw "check machines: the work laptop stub no longer sets ${toString missing}, so removing it proves nothing"
    else
      map (key: variant "without-private.${key}" identity (entry // { private = removeAttrs entry.private [ key ]; })) optional.private
      ++ map (key: variant "without-identity.${key}" (removeAttrs identity [ key ]) entry) optional.identity;

  keepOriginal = import ../modules/home/keep-original.nix { inherit pkgs; };

  fromSolutions = lib.concatMapAttrs
    (_: s: lib.optionalAttrs (s.checks != null)
      (s.checks (builtins.intersectAttrs (lib.functionArgs s.checks) { inherit pkgs inputs lib keepOriginal evalHome; })))
    dot.catalog.solutions;
in
fromSolutions // {
  resolver = decided "resolver" (import ./resolver.nix { inherit dot; });

  traits = decided "traits" (lib.concatLists (lib.mapAttrsToList
    (trait: t: map (value: "private-stub has no machine with ${trait} = ${builtins.toJSON value}")
      (lib.filter (value: !lib.any (m: lib.elem value (lib.toList m.traits.${trait})) (lib.attrValues stub)) t.values))
    dot.catalog.traits.schema));

  machines = pkgs.runCommand "check-machines" { } ''
    cat > $out <<'EOF'
    ${lib.concatStrings (lib.mapAttrsToList
      (name: m: "${name} ${builtins.unsafeDiscardStringContext m.build.drvPath}\n")
      stub)}${lib.concatMapStrings (v: "${v.name} ${builtins.unsafeDiscardStringContext v.machine.build.drvPath}\n") without}EOF
  '';

  machines-are-data = decided "machines-are-data" (lib.mapAttrsToList
    (name: m: "machine ${name} has ${toString m.extraModules} extraModules. Move them into a solution.")
    (lib.filterAttrs (_: m: m.extraModules > 0) real));

  root-reloads = decided "root-reloads" (lib.concatLists (lib.mapAttrsToList
    (name: m: lib.concatLists (lib.mapAttrsToList
      (id: step: map (path: "${name}: ${id} declares ${path} with no reload, and its reader reads it only when told")
        (lib.filter
          (path: step.files.${path}.reload == "" && lib.any (dir: lib.hasPrefix dir path)
            [ "/etc/systemd/system/" "/etc/systemd/resolved.conf.d/" "/etc/udev/rules.d/" "/etc/NetworkManager/conf.d/" ])
          (lib.attrNames step.files)))
      m.configuration.config.dotfiles.root))
    (lib.filterAttrs (_: m: m.platform == "linux") stub)));

  session-secrets =
    let
      homeOf = m: if m.platform == "darwin" then m.configuration.config.home-manager.users.${m.user.name} else m.configuration.config;
      problems = name: m:
        let
          h = homeOf m;
          writer = h.dotfiles.services.dotfiles-session-env or null;
          gui = m.platform == "linux" && !m.traits.headless;
          units = lib.optionalAttrs (m.platform == "linux") h.systemd.user.services;
          setsValues = lib.filterAttrs (_: u: lib.hasInfix "set-environment" (builtins.toJSON (u.Service or { }))) units;
        in
        lib.optional (writer == null) "${name}: no session env writer"
        ++ lib.optional (writer != null && lib.last writer.command != (if gui then "import" else "file-only"))
          "${name}: the session env writer ${if gui then "does not import" else "imports"} keys into the systemd user session"
        ++ map (u: "${name}: ${u} sets the user session environment, and values would be on its command line") (lib.attrNames setsValues)
        ++ map (u: "${name}: ${u} still writes a session env file of its own") (lib.filter (u: units ? ${u}) [ "infisical-env-sync" "bitwarden-env-sync" "api-keys" ]);
    in
    decided "session-secrets" (lib.concatLists (lib.mapAttrsToList problems stub));

  power-and-tailnet = decided "power-and-tailnet" (import ./power-and-tailnet.nix { inherit dot lib; });

  enablement = decided "enablement" (import ./enablement.nix { inherit dot lib; });

  provider-tooling = decided "provider-tooling" (import ./provider-tooling.nix { inherit dot lib; });

  integrations = decided "integrations" (import ./integrations.nix { inherit dot lib; });

  dev-extras = decided "dev-extras" (import ./dev-extras.nix { inherit dot lib; });

  mac-server = decided "mac-server" (import ./mac-server.nix { inherit dot lib; });

  t3code = decided "t3code" (import ./t3code.nix { inherit dot lib; });

  github-ssh = import ./github-ssh.nix { inherit dot lib pkgs; };

  tailscale-join = import ./tailscale-join.nix { inherit pkgs stub; };

  infisical-consumers = import ./infisical-consumers.nix { inherit lib pkgs stub; };

  credential-chain = import ./credential-chain.nix { inherit lib pkgs stub evalHome; };

  credential-delivery = import ./credential-delivery.nix { inherit lib pkgs stub evalHome; };

  secrets-audit = import ./secrets-audit.nix { inherit lib pkgs stub evalHome; };

  bitwarden-consumers = import ./bitwarden-consumers.nix { inherit dot lib pkgs stub; };

  no-secrets = import ./no-secrets.nix { inherit lib pkgs; machines = real; };

  no-secrets-bitwarden = import ./no-secrets.nix { inherit lib pkgs; machines = { inherit (stub) stub-bitwarden-server; }; };

  mutable = import ./mutable.nix { inherit pkgs evalHome; };

  root-apply = import ./root-apply.nix { inherit lib pkgs evalHome; };

  build-trust = import ./build-trust.nix { inherit lib pkgs stub evalHome; };

  home-guards = decided "home-guards" (import ./home-guards.nix { inherit dot evalHome; });

  services = decided "services" (import ./services.nix { inherit inputs lib; });

  dot-switch = import ./dot-switch.nix { inherit pkgs; };

  retire-chezmoi = import ./retire-chezmoi.nix { inherit pkgs evalHome; };

  private-closure = import ./private-closure.nix { inherit dot pkgs; };

  dot-shellcheck = pkgs.runCommand "check-dot-shellcheck" { nativeBuildInputs = [ pkgs.shellcheck ]; } ''
    shellcheck ${../dot} ${../bootstrap} ${../tools/leak-scan}
    touch $out
  '';

  no-comments = pkgs.runCommand "check-no-comments" { nativeBuildInputs = [ pkgs.python3 ]; } ''
    cd ${../.}
    python3 -I ${../tools/no-comments} .
    touch $out
  '';

  leak-scan = import ./leak-scan.nix { inherit lib pkgs; inherit (inputs) private; };
}

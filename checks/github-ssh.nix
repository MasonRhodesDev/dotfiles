{ dot, lib, pkgs }:
let
  identity = import ../private-stub/identity.nix;
  stub = dot.machinesFrom ../private-stub;
  desktop = import ../private-stub/machines/stub-gaming-desktop.nix;
  requirers = ids:
    let
      direct = lib.attrNames (lib.filterAttrs
        (id: sol: !(lib.elem id ids) && lib.any (r: lib.elem (lib.head (lib.splitString "@" r)) ids) sol.requires)
        dot.catalog.solutions);
    in
    if direct == [ ] then ids else requirers (ids ++ direct);
  variant = name: entry: dot.machineFrom identity name "stub-gaming-desktop, ${name}" entry;

  home = m: if m.platform == "darwin" then m.configuration.config.home-manager.users.${m.user.name} else m.configuration.config;

  rendered = {
    headless = stub.stub-headless;
    mac = stub.stub-thin-mac;
    desktop = stub.stub-gaming-desktop;
    privateGithub = variant "with a private github.com entry" (desktop // {
      private = desktop.private // { ssh = desktop.private.ssh // { "github.com" = { User = "git"; IdentityFile = "~/.ssh/github"; ControlPersist = "30m"; }; }; };
    });
  };
  withoutSsh = variant "without ssh" (desktop // { exclude = requirers [ "ssh" ]; });

  files = name: m:
    let h = home m; in
    {
      config = pkgs.writeText "${name}-ssh-config" h.home.file.".ssh/config".text;
      activation = pkgs.writeText "${name}-ssh-activation" (h.home.activation.sshDirMode.data + h.home.activation.sshControlDir.data);
    };

  probe = name: m:
    let f = files name m; in
    ''
      home=$PWD/home-${name}
      mkdir -p "$home"
      g() { HOME=$home ssh -F ${f.config} -G "$1" 2>/dev/null; }
      gh=$(g github.com)
      grep -qx 'controlmaster auto' <<< "$gh" || fail "${name}: github.com is not multiplexed"
      grep -Eqx 'controlpath .*/\.ssh/cm/[0-9a-f]{40}' <<< "$gh" || fail "${name}: github.com's control socket is not a %C hash under ~/.ssh/cm"
      grep -qx 'controlpersist ${if name == "privateGithub" then "1800" else "3600"}' <<< "$gh" || fail "${name}: github.com's master persists for the wrong time"
      for host in gitlab.com github.com.example.invalid example-nas dev; do
        other=$(g "$host")
        grep -qx 'controlmaster false' <<< "$other" || fail "${name}: $host is multiplexed"
        ! grep -q '^controlpath ' <<< "$other" || fail "${name}: $host has a control socket"
      done
      (run() { "$@"; }; HOME=$home; . ${f.activation}) || fail "${name}: activation failed"
      [ "$(stat -c %a "$home/.ssh/cm")" = 700 ] || fail "${name}: ~/.ssh/cm is not 0700"
    '';
in
assert lib.all (m: lib.all (id: lib.elem id m.enabled) [ "ssh" "git" ]) (lib.attrValues rendered);
assert lib.elem "git" withoutSsh.enabled && !(lib.elem "ssh" withoutSsh.enabled);
pkgs.runCommand "check-github-ssh" { nativeBuildInputs = [ pkgs.openssh ]; } ''
  fail() { echo "$*" >&2; exit 1; }
  ${lib.concatStrings (lib.mapAttrsToList probe rendered)}
  gh=$(HOME=$PWD/home-privateGithub ssh -F ${(files "privateGithub" rendered.privateGithub).config} -G github.com 2>/dev/null)
  grep -qx 'user git' <<< "$gh" || fail "privateGithub: the private github.com User is lost"
  [ "$(grep '^identityfile ' <<< "$gh" | head -n1)" = 'identityfile ~/.ssh/github' ] || fail "privateGithub: the private github.com IdentityFile does not come first"
  ${lib.concatStrings (lib.mapAttrsToList (name: m: lib.optionalString (!(lib.elem "linkGeneration" (home m).home.activation.sshControlDir.before)) ''fail "${name}: ~/.ssh/cm is made after the config that needs it goes live"
  '') rendered)}
  ${lib.optionalString ((home withoutSsh).home.activation ? sshControlDir) ''fail "without ssh: git still creates ~/.ssh/cm"''}
  ${lib.optionalString ((home withoutSsh).home.file ? ".ssh/config") ''fail "without ssh: an ssh config is still written"''}
  touch $out
''

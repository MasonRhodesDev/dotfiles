{ dot, lib }:
let
  linux = lib.filterAttrs (_: m: m.platform == "linux") (dot.machinesFrom ../private-stub);
  has = m: id: lib.elem id m.enabled;

  identity = import ../private-stub/identity.nix;
  desktop = import ../private-stub/machines/stub-gaming-desktop.nix;
  variant = name: id: change: dot.machineFrom id name "stub-gaming-desktop, ${name}" (change desktop);
  qbtMagnet = name: m: want:
    let
      c = m.configuration.config;
      config = c.xdg.configFile."qbt-magnet/config".text or null;
      warned = lib.any (w: lib.hasInfix "qbittorrent.url" w) c.dotfiles.warnings;
      claimed = c.dotfiles.mutable.".config/mimeapps.list".ini."Default Applications"."x-scheme-handler/magnet" or null;
    in
    lib.optional (has m "qbt-magnet" != want.on) "${name}: qbt-magnet is ${if want.on then "off" else "on"}"
    ++ lib.optional ((c.home.file ? ".local/bin/qbt-magnet") != want.on) "${name}: the magnet handler is ${if want.on then "missing" else "installed"}"
    ++ lib.optional (config != want.config) "${name}: ~/.config/qbt-magnet/config is ${builtins.toJSON config}, want ${builtins.toJSON want.config}"
    ++ lib.optional (claimed != (if want.config != null then "qbt-magnet.desktop" else null)) "${name}: the magnet: default in mimeapps.list is ${builtins.toJSON claimed}"
    ++ lib.optional (warned != want.warned) "${name}: ${if want.warned then "no" else "a"} warning about qbittorrent.url";
  web = { on = true; config = "QBT_URL=http://qbittorrent.example.invalid:8080\nQBT_USER=alex\n"; warned = false; };
  off = { on = false; config = null; warned = false; };
  magnet =
    qbtMagnet "stub-gaming-desktop" linux.stub-gaming-desktop web
    ++ qbtMagnet "an identity without a Web UI" (variant "no-web-ui" (removeAttrs identity [ "qbittorrent" ]) lib.id)
      { on = true; config = null; warned = true; }
    ++ qbtMagnet "no uses at all" (variant "no-uses" identity (e: e // { traits = e.traits // { uses = [ ]; }; })) web
    ++ qbtMagnet "headless" (variant "headless" identity (e: e // { traits = e.traits // { headless = true; form = "server"; uses = [ "dev" ]; hardware = [ ]; }; })) off
    ++ qbtMagnet "a work machine" (variant "work" identity (e: e // { traits = e.traits // { profile = "work"; uses = [ "dev" ]; }; })) off
    ++ lib.optional (lib.any (m: has m "qbt-magnet") (lib.attrValues (lib.filterAttrs (_: m: m.platform != "linux") (dot.machinesFrom ../private-stub))))
      "a personal Mac has qbt-magnet, which only runs on Linux";
in
magnet

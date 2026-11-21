{ dot, lib }:
let
  stub = dot.machinesFrom ../private-stub;
  homeOf = m: if m.platform == "darwin" then m.configuration.config.home-manager.users.${m.user.name} else m.configuration.config;
  installed = m: map lib.getName (homeOf m).home.packages;
  listed = m: m.private.packages or [ ];
  rule = tool: wanted: m:
    let has = lib.elem tool (installed m); want = wanted m || lib.elem tool (listed m); in
    lib.optional (has != want)
      "${m.name} (secrets = ${m.traits.secrets}${lib.optionalString (listed m != [ ]) ", private.packages = ${toString (listed m)}"}) ${if has then "installs" else "lacks"} ${tool}";
  provider = value: m: m.traits.secrets == value;
  rules = [
    (rule "rbw" (provider "bitwarden-vault"))
    (rule "bitwarden-cli" (provider "bitwarden-vault"))
    (rule "infisical" (provider "infisical"))
    (rule "bws" (provider "bitwarden"))
    (rule "pinentry-curses" (_: true))
  ];
  seen = value: lib.any (m: m.traits.secrets == value) (lib.attrValues stub);
in
lib.optional (!lib.any (m: listed m != [ ]) (lib.attrValues stub)) "no stub lists private.packages, so nothing proves the manual list installs a provider's tool"
++ map (value: "no stub has secrets = ${value}") (lib.filter (v: !seen v) [ "bitwarden-vault" "infisical" "bitwarden" "none" ])
++ lib.concatMap (m: lib.concatMap (r: r m) rules) (lib.attrValues stub)

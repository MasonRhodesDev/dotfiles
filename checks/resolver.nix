{ dot }:
let
  inherit (dot) lib;
  schema = import ./fixtures/traits.nix;
  catalog = dot.loadCatalog schema ./fixtures/catalog;
  resolve = dot.resolveIn catalog;
  desktop = { headless = false; profile = "personal"; form = "desktop"; gaming = false; hardware = [ ]; };
  on = system: args: resolve ({ inherit system; traits = desktop; } // args);
  linux = on "x86_64-linux";
  mac = on "aarch64-darwin";
  with' = facts: { traits = desktop // facts; };

  everywhere = [ "prompt" "shell" ];
  onLinuxDesktops = [ "bar" "paste" "prompt" "shell" "term" "wm" ];

  identity = import ../private-stub/identity.nix;
  entry = import ../private-stub/machines/stub-headless.nix;
  laptop = import ../private-stub/machines/stub-work-laptop.nix;
  accepted = entry: (builtins.tryEval (dot.machineFrom identity "fixture" "fixture.nix" entry).enabled).success;

  cases = {
    "unknown id is an error" = {
      got = (linux { include = [ "nope" ]; }).errors;
      want = [ "unknown node nope" ];
    };
    "unknown id in exclude is an error" = {
      got = (linux { exclude = [ "nope" ]; }).errors;
      want = [ "unknown node nope" ];
    };
    "a requirement the machine's facts rule out is an error" = {
      got = (linux (with' { headless = true; profile = "work"; })).errors;
      want = [ "work requires wm, not selected" ];
    };
    "requires is never auto-included" = {
      got = (linux (with' { headless = true; profile = "work"; })).enabled;
      want = [ "prompt" "shell" "work" ];
    };
    "conflict is an error" = {
      got = (linux (with' { profile = "work"; gaming = true; })).errors;
      want = [ "steam conflicts with work" ];
    };
    "a solution named directly on the wrong platform is an error" = {
      got = (mac { include = [ "bar" ]; }).errors;
      want = [ "bar named directly but unavailable on aarch64-darwin" ];
    };
    "a solution named directly on the wrong arch is an error" = {
      got = (on "aarch64-linux" (with' { gaming = true; } // { include = [ "steam" ]; })).errors;
      want = [ "steam named directly but unavailable on aarch64-linux" ];
    };
    "a group named directly skips what the platform lacks, silently" = {
      got = { inherit (mac (with' { gaming = true; } // { include = [ "desk.games" ]; })) enabled errors; };
      want = { enabled = [ "prompt" "shell" "term" "wm" ]; errors = [ ]; };
    };
    "a group skips what the platform lacks, silently" = {
      got = { inherit (mac { }) enabled errors; };
      want = { enabled = [ "prompt" "shell" "term" "wm" ]; errors = [ ]; };
    };
    "a group skips what the arch lacks, silently" = {
      got = { inherit (on "aarch64-linux" (with' { gaming = true; })) enabled errors; };
      want = { enabled = onLinuxDesktops; errors = [ ]; };
    };
    "a sub-group's when puts its children on the machine" = {
      got = { inherit (linux (with' { gaming = true; })) enabled errors; };
      want = { enabled = [ "bar" "paste" "prompt" "shell" "steam" "term" "wm" ]; errors = [ ]; };
    };
    "requires x@linux applies on Linux" = {
      got = (linux { exclude = [ "paste" ]; }).errors;
      want = [ "term requires paste@linux, not selected" ];
    };
    "requires x@linux does not apply on darwin" = {
      got = (mac { }).errors;
      want = [ ];
    };
    "exclude takes a solution out" = {
      got = { inherit (linux (with' { profile = "work"; } // { exclude = [ "prompt" ]; })) enabled errors; };
      want = { enabled = [ "bar" "paste" "shell" "term" "wm" "work" ]; errors = [ ]; };
    };
    "exclude takes a group out" = {
      got = (linux (with' { gaming = true; } // { exclude = [ "desk.games" ]; })).enabled;
      want = onLinuxDesktops;
    };
    "exclude can break a requirement" = {
      got = (linux { exclude = [ "shell" ]; }).errors;
      want = [ "prompt requires shell, not selected" ];
    };
    "a machine gets every solution its facts do not rule out" = {
      got = { inherit (linux { }) enabled errors; };
      want = { enabled = onLinuxDesktops; errors = [ ]; };
    };
    "a group skips what the machine's facts rule out, silently" = {
      got = { inherit (linux (with' { headless = true; })) enabled errors; };
      want = { enabled = everywhere; errors = [ ]; };
    };
    "a group's when covers every group and solution under it" = {
      got = { inherit (linux (with' { headless = true; gaming = true; hardware = [ "pad" ]; })) enabled errors; };
      want = { enabled = everywhere; errors = [ ]; };
    };
    "a solution's own when is matched against a list the machine states" = {
      got = { inherit (linux (with' { hardware = [ "pad" ]; })) enabled errors; };
      want = { enabled = [ "bar" "pad" "paste" "prompt" "shell" "term" "wm" ]; errors = [ ]; };
    };
    "a solution named directly that the machine's facts rule out is an error" = {
      got = (linux { include = [ "pad" ]; }).errors;
      want = [ "pad named directly but not for this machine (pad has when hardware = \"pad\")" ];
    };
    "a group named directly that the machine's facts rule out is an error" = {
      got = (linux { include = [ "office" ]; }).errors;
      want = [ "office named directly but not for this machine (office has when profile = \"work\")" ];
    };
    "naming a node under a group the machine's facts rule out is an error" = {
      got = (linux (with' { headless = true; gaming = true; } // { include = [ "desk.games" ]; })).errors;
      want = [ "desk.games named directly but not for this machine (desk has when headless = false)" ];
    };
    "a list in when puts the solution on a machine with any of its values" = {
      got = map (form: (linux (with' { inherit form; })).enabled) [ "laptop" "server" ];
      want = [ ([ "bar" "fan" ] ++ lib.tail onLinuxDesktops) ([ "bar" "fan" ] ++ lib.tail onLinuxDesktops) ];
    };
    "a solution named directly whose when lists none of the machine's values is an error" = {
      got = (linux { include = [ "fan" ]; }).errors;
      want = [ "fan named directly but not for this machine (fan has when form = [\"laptop\",\"server\"])" ];
    };
    "a list in when is checked value by value" = {
      got = map catalog.traits.whenProblems [
        { form = [ "laptop" "desktop" ]; profile = "work"; }
        { form = [ "laptop" "tablet" ]; }
        { form = [ ]; }
        { hardware = [ "pad" ]; }
      ];
      want = [
        [ ]
        [ "when form = \"tablet\" is not one of \"laptop\" \"desktop\" \"server\"" ]
        [ "when form = [] matches no machine" ]
        [ "when hardware = [\"pad\"]: hardware is a list trait, so name one value" ]
      ];
    };
    "include adds nothing the facts did not" = {
      got = { inherit (linux { include = [ "shell" "desk" ]; }) enabled errors; };
      want = { enabled = onLinuxDesktops; errors = [ ]; };
    };
    "why records the when of every node above each solution" = {
      got = (linux (with' { gaming = true; } // { exclude = [ "desk.games" "bar" "paste" "term" ]; })).why;
      want = {
        prompt = [ ];
        shell = [ ];
        wm = [ { node = "desk"; when = { headless = false; }; } ];
      };
    };
    "why lists a group's when before its sub-group's" = {
      got = (linux (with' { gaming = true; })).why.steam;
      want = [
        { node = "desk"; when = { headless = false; }; }
        { node = "desk.games"; when = { gaming = true; }; }
      ];
    };
    "a machine that states a trait nobody defined is refused" = {
      got = catalog.traits.problems (desktop // { office = true; });
      want = [ "unknown trait 'office' (traits: form gaming hardware headless profile)" ];
    };
    "a machine that states a value its trait does not have is refused" = {
      got = catalog.traits.problems (desktop // { profile = "home"; });
      want = [ "trait 'profile' is \"home\", not one of \"work\" \"personal\"" ];
    };
    "a machine that lists a value its trait does not have is refused" = {
      got = catalog.traits.problems (desktop // { hardware = [ "pad" "wheel" ]; });
      want = [ "trait 'hardware' has \"wheel\", not one of \"pad\"" ];
    };
    "a machine that states one value where a trait takes a list is refused" = {
      got = catalog.traits.problems (desktop // { hardware = "pad"; });
      want = [ "trait 'hardware' is \"pad\", not a list" ];
    };
    "a machine that leaves out a trait with no default is refused" = {
      got = catalog.traits.problems { headless = false; form = "laptop"; };
      want = [ "missing trait 'profile' (one of \"work\" \"personal\")" ];
    };
    "a trait with a default, or one that takes a list, may be left out" = {
      got = {
        problems = catalog.traits.problems { headless = true; profile = "work"; form = "server"; };
        filled = catalog.traits.fill { headless = true; profile = "work"; form = "server"; };
      };
      want = {
        problems = [ ];
        filled = { headless = true; profile = "work"; form = "server"; gaming = false; hardware = [ ]; };
      };
    };
    "a machine entry is checked against the traits before it resolves" = {
      got = map accepted [
        entry
        (entry // { traits = entry.traits // { office = true; }; })
        (entry // { traits = entry.traits // { headless = "sometimes"; }; })
        (entry // { target = "headless-agent-box"; })
        (entry // { include = [ "desktop" ]; })
        (entry // { exclude = [ "bash" ]; })
      ];
      want = [ true false false false false false ];
    };
    "the Infisical provider needs the solution that installs the infisical CLI" = {
      got = map accepted [ laptop (laptop // { exclude = [ "infisical-sync" "secret-inbox" ]; }) ];
      want = [ true false ];
    };
  } // lib.genAttrs [ "bad-key" "bad-requires" "bad-duplicate" "bad-slot" "bad-fragments" "bad-when-trait" "bad-when-value" "bad-group-key" ] (fixture: {
    got = (builtins.tryEval (dot.loadCatalog schema (./fixtures + "/${fixture}")).roots).success;
    want = false;
  });
in
lib.mapAttrsToList
  (name: c: "${name}: got ${builtins.toJSON c.got}, want ${builtins.toJSON c.want}")
  (lib.filterAttrs (_: c: c.got != c.want) cases)

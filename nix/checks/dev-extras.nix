{ dot, lib }:
let
  identity = import ../private-stub/identity.nix;
  entries = {
    headless = import ../private-stub/machines/stub-headless.nix;
    laptop = import ../private-stub/machines/stub-work-laptop.nix;
    desktop = import ../private-stub/machines/stub-gaming-desktop.nix;
  };
  requirers = ids:
    let
      direct = lib.attrNames (lib.filterAttrs
        (id: sol: !(lib.elem id ids) && lib.any (r: lib.elem (lib.head (lib.splitString "@" r)) ids) sol.requires)
        dot.catalog.solutions);
    in
    if direct == [ ] then ids else requirers (ids ++ direct);
  variant = base: name: change:
    let m = dot.machineFrom identity name "stub ${name}" (change entries.${base}); in
    { inherit name; inherit (m) enabled; config = m.configuration.config; home = m.user.home; };
  without = ids: entry: entry // { exclude = requirers ids; };
  withoutPrivate = key: entry: entry // { private = removeAttrs entry.private [ key ]; };

  host = variant "headless" "headless" (e: e);
  noClaude = variant "headless" "headless without claude-code" (without [ "claude-code" ]);
  noHerdr = variant "headless" "headless without herdr" (without [ "herdr" ]);
  noBash = variant "headless" "headless without bash" (without [ "bash" ]);
  noRoot = variant "headless" "headless without a build root" (withoutPrivate "ephBuildRoot");
  noCap = variant "headless" "headless without a herdr memory cap" (withoutPrivate "herdrMemoryMax");
  laptop = variant "laptop" "work laptop" (e: e);
  laptopNoKeyring = variant "laptop" "work laptop without the keyring" (without [ "keyring" ]);
  laptopNoClaude = variant "laptop" "work laptop without claude-code" (without [ "claude-code" ]);
  personal = variant "desktop" "personal desktop" (e: e);

  files = v: lib.mapAttrsToList (_: f: f.target) (lib.filterAttrs (_: f: f.enable) v.config.home.file);
  has = v: f: lib.elem f (files v);
  settings = v: v.config.dotfiles.mutable.".claude/settings.json" or { json = { }; adopt = null; };
  commands = hooks: lib.concatMap (e: map (h: h.command) e.hooks) (lib.concatLists (lib.attrValues hooks));
  hooked = v: script: lib.elem "${v.home}/.local/bin/${script}" (commands ((settings v).json.hooks or { }));
  adopted = v: script: lib.elem "$HOME/.local/bin/${script}" (commands (((settings v).adopt or { }).hooks or { }));
  unit = v: kind: name: v.config.systemd.user.${kind} ? ${name};
  memoryCap = v: v.config.xdg.configFile."systemd/user/herdr.service.d/memory.conf".text or null;
  workTemplates = v: lib.hasInfix ".claude/templates" (v.config.home.activation.workOverlay.data or "");
  mutable = v: path: v.config.dotfiles.mutable.${path} or null;

  holds = what: ok: lib.optional (!ok) what;
  resume = v: unit v "services" "herdr-resume-agents" && has v ".local/bin/herdr-resume-agents";
  offload = v: has v ".local/bin/cargo" && has v ".local/bin/eph-build-sweep" && unit v "timers" "eph-build-sweep";
  sessionMap = v: has v ".local/bin/herdr-session-map" && hooked v "herdr-session-map" && adopted v "herdr-session-map";
  guard = v: has v ".local/bin/claude-build-guard" && hooked v "claude-build-guard" && adopted v "claude-build-guard";
  noSessionMap = v: !(has v ".local/bin/herdr-session-map") && !(hooked v "herdr-session-map") && !(adopted v "herdr-session-map");
  noGuard = v: !(has v ".local/bin/claude-build-guard") && !(hooked v "claude-build-guard") && !(adopted v "claude-build-guard");
  wrappers = v: has v ".bashrc.d/agent-status.bashrc" && has v "scripts/agent-status-runner.ts" && has v "scripts/agent-status-codex.ts";
in
lib.concatMap (id: holds "the headless stub enables ${id}, so its gates are checked" (lib.elem id host.enabled))
  [ "herdr" "herdr-resume" "claude-code" "build-offload" "agent-pane-status" "bash" ]
++ holds "headless: herdr-resume's unit and script, started with each herdr start" (resume host && host.config.systemd.user.services.herdr-resume-agents.Install.WantedBy == [ "herdr.service" ])
++ holds "headless: the session map hook, its script, and the adopted overlay hook" (sessionMap host)
++ holds "headless: the cargo shim, the sweep and its timer" (offload host)
++ holds "headless: the build guard hook, its script, and the adopted overlay hook" (guard host)
++ holds "headless: herdr's memory cap from the machine entry" (memoryCap host == "[Service]\nMemoryMax=4G\n")
++ holds "without claude-code: no session map and no build guard" (noSessionMap noClaude && noGuard noClaude)
++ holds "without claude-code: herdr-resume and the cargo shim stay" (resume noClaude && offload noClaude)
++ holds "without herdr: nothing of herdr-resume" (!(resume noHerdr) && !(unit noHerdr "services" "herdr-resume-agents") && noSessionMap noHerdr)
++ holds "without herdr: the build guard stays" (guard noHerdr)
++ holds "without a build root: no shim, sweep, timer or guard" (!(has noRoot ".local/bin/cargo") && !(has noRoot ".local/bin/eph-build-sweep") && !(unit noRoot "timers" "eph-build-sweep") && !(unit noRoot "services" "eph-build-sweep") && noGuard noRoot)
++ holds "without a build root: herdr-resume stays" (resume noRoot && sessionMap noRoot)
++ holds "without a memory cap: no drop-in" (memoryCap noCap == null)
++ holds "headless with bash and no kitty: the Codex and pi wrappers and their runner" (wrappers host && !(has host "scripts/terminal-session-task-stack.ts"))
++ holds "without bash: no wrappers, and the bridge stays for Codex and pi" (!(wrappers noBash) && has noBash "scripts/agent-status-bridge.ts")
++ holds "Codex's hooks.json is merged, private, and written only where the Codex install the wrapper runs is" (lib.attrByPath [ "whenPresent" ] null (mutable host ".codex/hooks.json") == ".npm-global/lib/node_modules/@openai/codex" && (mutable host ".codex/hooks.json").mode == "0600" && (mutable host ".codex/hooks.json").strategy == "merge-json")
++ holds "the pi extension is written only where ~/.pi/agent is" (lib.attrByPath [ "whenPresent" ] null (mutable host ".pi/agent/extensions/agent-status.ts") == ".pi/agent")
++ holds "the work laptop with Claude Code has slack-mcp" (has laptop ".local/bin/slack-mcp")
++ holds "without the keyring, slack-mcp stays, since its tokens can come from the provider" (has laptopNoKeyring ".local/bin/slack-mcp")
++ holds "without claude-code, no slack-mcp" (!(has laptopNoClaude ".local/bin/slack-mcp"))
++ holds "a personal machine with the keyring and Claude Code has no slack-mcp" (lib.all (id: lib.elem id personal.enabled) [ "keyring" "claude-code" ] && !(has personal ".local/bin/slack-mcp"))
++ holds "the work overlay copies Claude's templates where Claude Code is" (workTemplates laptop)
++ holds "without claude-code, the work overlay still syncs and copies no templates" (laptopNoClaude.config.home.activation ? workOverlay && !(workTemplates laptopNoClaude))
++ holds "herdr's service finds a node from the store before the distro's" (lib.any (e: builtins.match "PATH=.*/nix/store/[^:]*-nodejs-[^:]*/bin:.*/usr/bin.*" e != null) host.config.systemd.user.services.herdr.Service.Environment)
++ holds "t3code's PATH drop-in has a node from the store before the distro's" (builtins.match ".*PATH=.*/nix/store/[^:]*-nodejs-[^:]*/bin:.*/usr/bin.*" host.config.xdg.configFile."systemd/user/t3code.service.d/path.conf".text != null)
++ holds "rust brings cargo-deny" (lib.any (p: (p.pname or "") == "cargo-deny") host.config.home.packages)

{ dot, lib }:
let
  identity = import ../private-stub/identity.nix;
  entry = import ../private-stub/machines/stub-work-laptop.nix;
  hosts = [ "bash" "kitty" "notifications" "git" "rust" "window-manager" "tmux" ];
  requirers = ids:
    let
      direct = lib.attrNames (lib.filterAttrs
        (id: sol: !(lib.elem id ids) && lib.any (r: lib.elem (lib.head (lib.splitString "@" r)) ids) sol.requires)
        dot.catalog.solutions);
    in
    if direct == [ ] then ids else requirers (ids ++ direct);
  variant = name: exclude:
    let m = dot.machineFrom identity name "stub-work-laptop, ${name}" (entry // { inherit exclude; }); in
    { inherit name; inherit (m) enabled; config = m.configuration.config; };
  variants = {
    all = variant "all" [ ];
    noClaude = variant "without claude-code" [ "claude-code" ];
    noStatus = variant "without agent-pane-status" [ "agent-pane-status" ];
    noNotifications = variant "without notifications" [ "notifications" ];
    noHosts = variant "without bash, kitty, notifications, git, rust, the window manager and what requires them" (requirers hosts);
  };

  claudeSettings = v: v.config.dotfiles.mutable.".claude/settings.json" or { json = { }; adopt = null; };
  commands = hooks: lib.concatMap (e: map (h: h.command) e.hooks) (lib.concatLists (lib.attrValues hooks));
  statusHooks = v: lib.filter (lib.hasInfix "/scripts/agent-status-claude-") (commands ((claudeSettings v).json.hooks or { }));
  adopted = v: commands (((claudeSettings v).adopt or { }).hooks or { });
  both = v: lib.all (id: lib.elem id v.enabled) [ "claude-code" "agent-pane-status" ];
  files = v: lib.mapAttrsToList (_: f: f.target) (lib.filterAttrs (_: f: f.enable) v.config.home.file);
  under = prefix: v: lib.filter (lib.hasPrefix prefix) (files v);

  iff = v:
    lib.optional (both v && statusHooks v == [ ]) "${v.name}: claude-code and agent-pane-status are both on, and no agent status hook is registered"
    ++ lib.optional (!(both v) && statusHooks v != [ ]) "${v.name}: an agent status hook is registered without both claude-code and agent-pane-status"
    ++ lib.optional (both v && lib.length (adopted v) != 6) "${v.name}: agent-pane-status does not adopt the six wezterm-claude hooks it replaced"
    ++ lib.optional (!(both v) && adopted v != [ ]) "${v.name}: the wezterm-claude hooks are adopted without both claude-code and agent-pane-status";

  deployed = v:
    let home = v.config.home.homeDirectory; in
    map (c: "${v.name}: the hook ${c} runs no file this generation deploys")
      (lib.filter (c: !(lib.hasPrefix "${home}/" c && lib.elem (lib.removePrefix "${home}/" (lib.head (lib.splitString " " c))) (files v)))
        (commands ((claudeSettings v).json.hooks or { }) ++ commands ((v.config.dotfiles.mutable.".codex/hooks.json" or { json = { }; }).json.hooks or { })));

  hostless = v:
    map (f: "${v.name}: ${f} is written with bash off") (under ".bashrc.d/" v)
    ++ map (f: "${v.name}: ${f} is written with kitty off") (under ".config/kitty/" v ++ under ".config/lmtt/modules/kitty" v ++ lib.filter (lib.hasSuffix "terminal-session-task-stack.ts") (files v))
    ++ map (f: "${v.name}: ${f} is written with bash off") (lib.filter (f: lib.elem f [ "scripts/agent-status-runner.ts" "scripts/agent-status-codex.ts" "scripts/agent-status-pi.ts" ]) (files v))
    ++ lib.optional (v.config.dotfiles.mutable ? ".config/kitty/kitty.conf") "${v.name}: kitty.conf is written with kitty off"
    ++ lib.optional (v.config.programs.git.ignores != [ ]) "${v.name}: git ignores are set with git off"
    ++ lib.optional (lib.elem ".local/bin/rust-analyzer" (files v)) "${v.name}: the rust-analyzer shim is written with rust off"
    ++ map (f: "${v.name}: ${f} is written with the window manager off") (under ".config/lmtt/modules/hyprtoolkit" v ++ under ".config/lmtt/scripts/hyprtoolkit" v);

  present = v:
    lib.optional (under ".bashrc.d/agent-status" v == [ ]) "${v.name}: the Codex and pi wrappers are missing with bash on"
    ++ lib.optional (!(v.config.dotfiles.mutable ? ".codex/hooks.json")) "${v.name}: Codex's hooks.json is missing"
    ++ lib.optional (!(lib.elem "scripts/terminal-session-task-stack.ts" (files v))) "${v.name}: the task stack library is missing with kitty on"
    ++ lib.optional (!(lib.elem "scripts/agent-status-bridge.ts" (files v))) "${v.name}: the bridge is missing with kitty on"
    ++ lib.optional (under ".config/hypr-de/notify-plugins/" v == [ ]) "${v.name}: slack's notify plugins are missing with notifications on"
    ++ lib.optional (v.config.programs.git.ignores == [ ]) "${v.name}: Claude's git ignore is missing with git on"
    ++ lib.optional (!(lib.elem ".local/bin/rust-analyzer" (files v))) "${v.name}: the rust-analyzer shim is missing with rust on"
    ++ lib.optional (!(lib.hasInfix "include lmtt-colors.conf" v.config.dotfiles.mutable.".config/kitty/kitty.conf".text)) "${v.name}: lmtt's include is missing from kitty.conf"
    ++ lib.optional (!(lib.hasInfix "watcher watcher.py" v.config.dotfiles.mutable.".config/kitty/kitty.conf".text)) "${v.name}: terminal-header's watcher is missing from kitty.conf"
    ++ lib.optional (!(lib.hasInfix "lmtt-colors.conf" v.config.dotfiles.mutable.".tmux.conf".text)) "${v.name}: lmtt's colours are missing from tmux.conf"
    ++ lib.optional (!(lib.hasInfix "gen herdr" v.config.home.file.".local/bin/refresh-completions".text)) "${v.name}: herdr's completion is missing from refresh-completions";

  expected = [ "agent-pane-status" "claude-code" "kitty" "bash" "notifications" "slack" "git" "rust" "terminal-header" "lmtt" "tmux" "herdr" ];
  stubHas = lib.subtractLists variants.all.enabled expected;
in
if stubHas != [ ] then [ "the work laptop stub no longer enables ${toString stubHas}, so excluding it proves nothing" ]
else
  lib.concatMap iff (lib.attrValues variants)
  ++ lib.concatMap deployed [ variants.all variants.noStatus ]
  ++ present variants.all
  ++ hostless variants.noHosts
  ++ map (f: "${variants.noNotifications.name}: ${f} is written with notifications off") (under ".config/hypr-de/notify-plugins/" variants.noNotifications)
  ++ lib.optional (!(lib.elem "slack" variants.noNotifications.enabled)) "slack is not on without notifications, so its plugins' condition is never checked"

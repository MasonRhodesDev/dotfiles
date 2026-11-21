let
  claudeHooks = home: names:
    let
      hook = scripts: { matcher = ""; hooks = map (n: { type = "command"; command = "${home}/scripts/${n}"; }) scripts; };
      activity = names.activity;
    in
    {
      SessionStart = [ (hook [ names.session activity ]) ];
      UserPromptSubmit = [ (hook [ activity ]) ];
      PostToolUse = [ (hook [ activity ]) ];
      Stop = [ (hook [ activity ]) ];
      SessionEnd = [ (hook [ names.cleanup ]) ];
    };
  codexHooks = home:
    let
      bridge = { hooks = [{ type = "command"; command = "${home}/scripts/agent-status-bridge.ts codex"; timeout = 5; }]; };
    in
    {
      SessionStart = [ bridge ];
      UserPromptSubmit = [ bridge ];
      PreToolUse = [ bridge ];
      PostToolUse = [ bridge ];
      Stop = [ bridge ];
    };
in
{
  name = "Agent pane status";
  description = "Reports Claude, Codex and pi activity into kitty panes, locally or from the far end of SSH: Claude hooks where Claude Code is; the bridge, registered in Codex's hooks.json where the npm install of Codex that the wrapper runs is and called by a pi extension where ~/.pi/agent is; with bash the Codex and pi wrappers and their runner; and with kitty the task stack library.";
  platforms = [ "linux" "darwin" ];
  requires = [ "node" ];

  linux.home = { config, lib, machine, ... }:
    let
      home = config.home.homeDirectory;
      has = id: lib.elem id machine.enabled;
      fill = file: builtins.replaceStrings [ "@home@" ] [ home ] (builtins.readFile file);
      script = name: lib.nameValuePair "scripts/${name}" { text = fill ./${name}; executable = true; };
      kitty = has "kitty";
    in
    lib.mkMerge [
      (lib.mkIf (has "claude-code") {
        dotfiles.mutable.".claude/settings.json" = {
          strategy = "merge-json";
          json.hooks = claudeHooks home {
            session = "agent-status-claude-session-hook";
            activity = "agent-status-claude-activity-hook";
            cleanup = "agent-status-claude-cleanup-hook";
          };
          adopt.hooks = claudeHooks home {
            session = "wezterm-claude-session-hook";
            activity = "wezterm-claude-activity-hook";
            cleanup = "wezterm-claude-cleanup-hook";
          };
        };
        home.file = lib.listToAttrs (map script [
          "agent-status-claude-session-hook"
          "agent-status-claude-activity-hook"
          "agent-status-claude-cleanup-hook"
          "agent-status-claude-summarize"
        ]);
      })
      {
        home.file = lib.listToAttrs [ (script "agent-status-bridge.ts") ];
        dotfiles.mutable.".codex/hooks.json" = {
          strategy = "merge-json";
          mode = "0600";
          whenPresent = ".npm-global/lib/node_modules/@openai/codex";
          json.hooks = codexHooks home;
        };
        dotfiles.mutable.".pi/agent/extensions/agent-status.ts" = {
          strategy = "overwrite";
          whenPresent = ".pi/agent";
          text = fill ./agent-status-pi-extension.ts;
        };
      }
      (lib.mkIf kitty {
        home.file."scripts/terminal-session-task-stack.ts" = { source = ./terminal-session-task-stack.ts; executable = true; };
      })
      (lib.mkIf (has "bash") {
        home.file = lib.listToAttrs (map script [
          "agent-status-runner.ts"
          "agent-status-codex.ts"
          "agent-status-pi.ts"
        ]) // {
          ".bashrc.d/agent-status.bashrc".text = fill ./agent-status.bashrc;
        };
      })
    ];

  inventory = {
    files = [
      ".claude/settings.json#agent-pane-status"
      ".codex/hooks.json"
      ".pi/agent/extensions/agent-status.ts"
      "scripts/agent-status-claude-session-hook"
      "scripts/agent-status-claude-activity-hook"
      "scripts/agent-status-claude-cleanup-hook"
      "scripts/agent-status-claude-summarize"
      "scripts/agent-status-bridge.ts"
      "scripts/agent-status-runner.ts"
      "scripts/agent-status-codex.ts"
      "scripts/agent-status-pi.ts"
      "scripts/terminal-session-task-stack.ts"
      ".bashrc.d/agent-status.bashrc"
    ];
  };
}

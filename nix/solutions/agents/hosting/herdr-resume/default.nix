let
  hook = command: { hooks = [{ type = "command"; inherit command; }]; };
in
{
  name = "herdr resume";
  description = "Puts each Claude session back into the herdr pane it ran in after herdr restarts: a oneshot that every herdr start pulls in, where herdr is, and the Claude SessionStart hook that records pane to session, where Claude Code is too.";
  platforms = [ "linux" ];

  linux.home = { config, lib, pkgs, machine, ... }:
    let
      home = config.home.homeDirectory;
      has = id: lib.elem id machine.enabled;
      script = name: {
        text = builtins.replaceStrings [ "@jq@" ] [ "${pkgs.jq}" ] (builtins.readFile ./${name});
        executable = true;
      };
    in
    lib.mkIf (has "herdr") (lib.mkMerge [
      {
        home.file.".local/bin/herdr-resume-agents" = script "herdr-resume-agents";
        systemd.user.services.herdr-resume-agents = {
          Unit = {
            Description = "Resume Claude agents in the herdr panes they were running in";
            After = [ "herdr.service" ];
            Wants = [ "herdr.service" ];
            ConditionPathExists = "%h/.local/state/herdr-resume/panes.json";
          };
          Service = {
            Type = "oneshot";
            ExecStart = "%h/.local/bin/herdr-resume-agents";
            Environment = [ "PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin" ];
            TimeoutStartSec = 1800;
            Nice = 10;
          };
          Install.WantedBy = [ "herdr.service" ];
        };
      }
      (lib.mkIf (has "claude-code") {
        home.file.".local/bin/herdr-session-map" = script "herdr-session-map";
        dotfiles.mutable.".claude/settings.json" = {
          strategy = "merge-json";
          json.hooks.SessionStart = [ (hook "${home}/.local/bin/herdr-session-map") ];
          adopt.hooks.SessionStart = [ (hook "$HOME/.local/bin/herdr-session-map") ];
        };
      })
    ]);

  inventory = {
    starts = {
      linux = [ "herdr-resume-agents.service (with each herdr.service start)" ];
    };
    files = [
      ".local/bin/herdr-resume-agents"
      ".local/bin/herdr-session-map"
      ".config/systemd/user/herdr-resume-agents.service"
      ".claude/settings.json#herdr-resume"
    ];
  };
}

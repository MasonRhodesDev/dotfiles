{
  name = "Reap orphan ssh-agents";
  description = "Kills ssh-agents left in closing logind sessions, which JumpCloud remote-assist churns through.";
  platforms = [ "linux" ];

  linux.home = { ... }: {
    home.file.".local/bin/reap-orphan-ssh-agents" = { source = ./reap-orphan-ssh-agents; executable = true; };

    systemd.user.services.reap-orphan-ssh-agents = {
      Unit.Description = "Kill ssh-agents stranded in closing login sessions";
      Service = {
        Type = "oneshot";
        ExecStart = "%h/.local/bin/reap-orphan-ssh-agents";
        Nice = 19;
      };
    };
    systemd.user.timers.reap-orphan-ssh-agents = {
      Unit.Description = "Reap orphan ssh-agents every 15 minutes";
      Timer = {
        OnBootSec = "5min";
        OnUnitActiveSec = "15min";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
